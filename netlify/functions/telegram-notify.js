// Netlify Function — Telegram Notification on New Order
// Triggered by Supabase Database Webhook (INSERT on orders table).
// Telegram Bot API is free with effectively no monthly message cap
// (rate limit ~30 msg/sec), unlike the LINE push-message quota.
//
// Environment variables required (set in Netlify dashboard):
//   TELEGRAM_BOT_TOKEN   — Bot token from @BotFather (e.g. 123456:ABC-DEF...)
//   TELEGRAM_CHAT_ID     — Target chat id(s), comma-separated. For a group
//                          this is a NEGATIVE number (e.g. -1001234567890).
//   SUPABASE_URL         — Supabase project URL
//   SUPABASE_SERVICE_KEY — Supabase service-role key (bypasses RLS to read
//                          the order; required after migration 022)
//   SUPABASE_ANON_KEY    — Supabase anon public key (fallback only)
//   WEBHOOK_SECRET       — Secret string to verify the request is from Supabase

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  // Verify webhook secret (same header Supabase already sends to line-notify)
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

    // Re-fetch the order + items fresh from the DB (one query). Same reasons
    // as line-notify.js: (1) create_order() inserts total_price=0 then UPDATEs
    // it, so the webhook snapshot total is stale; (2) after migration 022 the
    // order tables are only readable with the service-role key.
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
    const order = (Array.isArray(orderRows) && orderRows[0]) ? orderRows[0] : record;
    const items = order.order_items || [];

    // Build message — plain text (no parse_mode) so arbitrary customer names
    // and notes never need Telegram Markdown/HTML escaping.
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

    // Send to all chat ids (comma-separated support, e.g. group + owner DM)
    const token = process.env.TELEGRAM_BOT_TOKEN;
    const chatIds = (process.env.TELEGRAM_CHAT_ID || '')
      .split(',')
      .map(id => id.trim())
      .filter(Boolean);

    if (!token || !chatIds.length) {
      console.error('TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not configured');
      return { statusCode: 200, body: 'Telegram not configured' };
    }

    const results = await Promise.all(
      chatIds.map(chatId =>
        fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: chatId,
            text:    messageText,
            disable_web_page_preview: true,
          }),
        })
      )
    );

    const failed = results.filter(r => !r.ok);
    if (failed.length) {
      const errText = await failed[0].text();
      console.error('Telegram API error:', errText);
      return { statusCode: 500, body: 'Telegram API error: ' + errText };
    }

    console.log(`Telegram notification sent for order ${order.order_no}`);
    return { statusCode: 200, body: 'OK' };

  } catch (err) {
    console.error('Function error:', err);
    return { statusCode: 500, body: err.message };
  }
};
