// Netlify Function — LINE Notification on New Order
// Triggered by Supabase Database Webhook (INSERT on orders table)
// Environment variables required (set in Netlify dashboard):
//   LINE_CHANNEL_TOKEN  — LINE Messaging API channel access token
//   LINE_USER_ID        — Owner's LINE user ID (comma-separated for multiple)
//   SUPABASE_URL         — Supabase project URL
//   SUPABASE_SERVICE_KEY — Supabase service-role key (bypasses RLS to read the
//                          order; required after migration 022 locks down anon reads)
//   SUPABASE_ANON_KEY    — Supabase anon public key (fallback only)
//   WEBHOOK_SECRET       — Secret string to verify the request is from Supabase

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  // Verify webhook secret
  const secret = event.headers['x-webhook-secret'] || event.headers['X-Webhook-Secret'];
  if (secret !== process.env.WEBHOOK_SECRET) {
    console.error('Invalid webhook secret');
    return { statusCode: 401, body: 'Unauthorized' };
  }

  try {
    const payload = JSON.parse(event.body);

    // Only handle new orders
    if (payload.type !== 'INSERT' || payload.table !== 'orders') {
      return { statusCode: 200, body: 'Ignored' };
    }

    const record = payload.record;

    // Re-fetch the order + items fresh from the DB (one query), for TWO reasons:
    //  1. create_order() inserts the order with total_price=0 and UPDATEs the
    //     real total later in the same transaction, so the webhook's `record`
    //     snapshot has a stale ฿0 total. The committed DB row is correct.
    //  2. After migration 022 locks down RLS, order_items / orders are only
    //     readable with the SERVICE-role key — the anon key no longer works
    //     here. The service key (already used by invite-user.js) bypasses RLS,
    //     which is the correct choice for a trusted server-side webhook.
    const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY;

    const orderRes = await fetch(
      `${process.env.SUPABASE_URL}/rest/v1/orders?id=eq.${record.id}&select=order_no,customer_name,customer_phone,customer_address,total_price,note,order_items(menu_name,qty,unit_price,note,order_item_options(group_name,choice_name,additional_price))`,
      {
        headers: {
          'apikey':        SERVICE_KEY,
          'Authorization': `Bearer ${SERVICE_KEY}`,
        }
      }
    );
    const orderRows = await orderRes.json();
    // Fall back to the webhook snapshot if the fresh fetch fails for any reason.
    const order = (Array.isArray(orderRows) && orderRows[0]) ? orderRows[0] : record;
    const items = order.order_items || [];

    // Build LINE message — same format as the original GAS backend
    const lines = [];
    lines.push('📥 ออเดอร์ใหม่ — ' + order.order_no);
    lines.push('────────────────');
    lines.push('👤 ' + (order.customer_name    || '-'));
    lines.push('📞 ' + (order.customer_phone   || '-'));
    lines.push('📍 ' + (order.customer_address || '-'));
    lines.push('');
    lines.push('รายการ:');

    (items || []).forEach((item, i) => {
      const subtotal = (item.unit_price || 0) * (item.qty || 1);
      lines.push((i + 1) + '. ' + (item.menu_name || '-') + ' x' + item.qty + ' = ' + subtotal + '฿');

      // Options: "   • group_name: choice_name" (truncated to 3 words, no price suffix)
      (item.order_item_options || []).forEach(opt => {
        const val = (opt.choice_name || '')
          .trim()
          .split(/\s+/)
          .slice(0, 3)
          .join(' ');
        lines.push('   • ' + (opt.group_name || '') + ': ' + val);
      });

      if (item.note) lines.push('   หมายเหตุ: ' + item.note);
    });

    lines.push('');
    lines.push('💰 ยอดรวม: ' + order.total_price + ' บาท');

    if (order.note) {
      lines.push('');
      lines.push('หมายเหตุ: ' + order.note);
    }

    const messageText = lines.join('\n');

    // Send to all LINE user IDs (comma-separated support)
    const userIds = (process.env.LINE_USER_ID || '')
      .split(',')
      .map(id => id.trim())
      .filter(Boolean);

    if (!userIds.length) {
      console.error('No LINE_USER_ID configured');
      return { statusCode: 200, body: 'No LINE user ID set' };
    }

    const results = await Promise.all(
      userIds.map(uid =>
        fetch('https://api.line.me/v2/bot/message/push', {
          method:  'POST',
          headers: {
            'Content-Type':  'application/json',
            'Authorization': `Bearer ${process.env.LINE_CHANNEL_TOKEN}`,
          },
          body: JSON.stringify({
            to:       uid,
            messages: [{ type: 'text', text: messageText }],
          }),
        })
      )
    );

    const failed = results.filter(r => !r.ok);
    if (failed.length) {
      const errText = await failed[0].text();
      console.error('LINE API error:', errText);
      return { statusCode: 500, body: 'LINE API error: ' + errText };
    }

    console.log(`LINE notification sent for order ${order.order_no}`);
    return { statusCode: 200, body: 'OK' };

  } catch (err) {
    console.error('Function error:', err);
    return { statusCode: 500, body: err.message };
  }
};
