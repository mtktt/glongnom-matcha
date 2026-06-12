/**
 * receipt.js — Shared receipt builder for Glongnom POS
 * Supports 58mm thermal paper (XPrinter XP-58IIL and compatible)
 *
 * Usage:
 *   printOrderReceipt(order, shopConfig)
 *   testPrintReceipt(shopConfig)
 *   buildReceiptHTML(order, shopConfig)  → returns HTML string
 */

// ── HELPERS ──────────────────────────────────────────────────────────────────

function _esc(str) {
  return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function _fmt(num) {
  return Number(num || 0).toFixed(2);
}

// ── RECEIPT HTML BUILDER ──────────────────────────────────────────────────────

function buildReceiptHTML(order, shopConfig) {
  const cfg = shopConfig || {};

  const shopName    = cfg.name         || 'GLONGNOM';
  const shopTagline = cfg.tagline_th   || 'มัทฉะคราฟท์สดใหม่';
  const shopPhone   = cfg.phone        || '';
  const shopIG      = cfg.ig           || '@glongnom_matcha';
  const thankMsg    = cfg.thank_you    || 'ขอบคุณที่อุดหนุนนะคะ ♡';
  const seeAgain    = cfg.see_again    || 'กลับมาอีกนะคะ 🌿';

  const date    = new Date(order.created_at || Date.now());
  const dateStr = date.toLocaleDateString('th-TH', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeStr = date.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' });

  const typeMap  = { delivery: 'Delivery', pickup: 'Pickup', 'dine-in': 'Dine-in' };
  const typeLabel = typeMap[order.order_type] || _esc(order.order_type || '—');
  const tableInfo = order.table_no ? ` · Table ${order.table_no}` : '';

  // Items rows
  const itemRows = (order.order_items || []).map(item => {
    const qty       = item.qty || 1;
    const unitPrice = Number(item.unit_price || 0);
    const lineTotal = _fmt(unitPrice * qty);
    const opts      = (item.order_item_options || []).map(o => _esc(o.choice_name || '')).filter(Boolean).join(', ');

    return `
    <tr>
      <td class="td-name">${qty}x ${_esc(item.menu_name || '—')}</td>
      <td class="td-price">${lineTotal}</td>
    </tr>
    ${opts ? `<tr><td colspan="2" class="td-sub">• ${opts}</td></tr>` : ''}
    ${item.note ? `<tr><td colspan="2" class="td-sub">📝 ${_esc(item.note)}</td></tr>` : ''}`;
  }).join('');

  const subtotal  = Number(order.subtotal     || order.total_price || 0);
  const delivery  = Number(order.delivery_fee || 0);
  const total     = Number(order.total_price  || 0);

  const subRows = delivery > 0
    ? `<tr><td>ยอดสินค้า</td><td class="td-price">${_fmt(subtotal)}</td></tr>
       <tr><td>ค่าจัดส่ง</td><td class="td-price">${_fmt(delivery)}</td></tr>`
    : '';

  return `<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<title>Receipt #${_esc(order.order_no || 'TEST')}</title>
<style>
  @page {
    size: 58mm auto;
    margin: 2mm 1mm;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: 56mm;
    max-width: 56mm;
    font-family: 'Courier New', Courier, monospace;
    font-size: 9pt;
    line-height: 1.55;
    color: #000;
    background: #fff;
    padding: 1mm 0 8mm;
  }
  .center     { text-align: center; }
  .shop-name  { font-size: 13pt; font-weight: bold; text-align: center; letter-spacing: 0.02em; }
  .shop-sub   { font-size: 7.5pt; text-align: center; color: #222; }
  .meta       { font-size: 8.5pt; line-height: 1.6; }
  hr.d        { border: none; border-top: 1px dashed #000; margin: 2.5mm 0; width: 100%; }
  hr.s        { border: none; border-top: 1.5px solid #000; margin: 2mm 0; width: 100%; }
  table       { width: 100%; border-collapse: collapse; }
  td          { vertical-align: top; font-size: 9pt; padding: 0.8mm 0; }
  .td-name    { width: 68%; word-break: break-word; }
  .td-price   { width: 32%; text-align: right; white-space: nowrap; }
  .td-sub     { font-size: 7.5pt; color: #333; padding-left: 4mm; padding-bottom: 1.5mm; }
  .total-row td { font-size: 11pt; font-weight: bold; padding-top: 1.5mm; }
  .thanks     { text-align: center; margin-top: 3.5mm; font-size: 9pt; }
  .thanks-sm  { text-align: center; font-size: 7.5pt; color: #333; margin-top: 1mm; }
  @media print {
    body   { width: 56mm; }
    @page  { margin: 2mm 1mm; }
  }
</style>
</head>
<body>

<div class="shop-name">🍵 ${_esc(shopName)} 🍵</div>
<div class="shop-sub">${_esc(shopTagline)}</div>
${shopPhone ? `<div class="shop-sub">Tel: ${_esc(shopPhone)}</div>` : ''}

<hr class="s">

<div class="meta">${dateStr}&nbsp;&nbsp;${timeStr}</div>
<div class="meta">Order <b>#${_esc(order.order_no || '—')}</b>&nbsp;|&nbsp;${typeLabel}${tableInfo}</div>

<hr class="d">

<div class="meta"><b>ชื่อ:&nbsp;</b>${_esc(order.customer_name  || '—')}</div>
<div class="meta"><b>โทร:&nbsp;</b>${_esc(order.customer_phone || '—')}</div>
${order.customer_address ? `<div class="meta"><b>ส่งที่:&nbsp;</b>${_esc(order.customer_address)}</div>` : ''}
${order.note              ? `<div class="meta">📝&nbsp;${_esc(order.note)}</div>`                        : ''}

<hr class="d">

<table><tbody>${itemRows}</tbody></table>

<hr class="d">

<table><tbody>${subRows}</tbody></table>
<hr class="s">
<table><tbody>
  <tr class="total-row">
    <td>รวมทั้งหมด</td>
    <td class="td-price">${_fmt(total)}&nbsp;฿</td>
  </tr>
</tbody></table>
<hr class="s">

<div class="thanks">${_esc(thankMsg)}</div>
<div class="thanks">${_esc(seeAgain)}</div>
<div class="thanks-sm">${_esc(shopIG)}</div>

</body>
</html>`;
}

// ── PRINT FUNCTIONS ───────────────────────────────────────────────────────────

function printOrderReceipt(order, shopConfig) {
  const html   = buildReceiptHTML(order, shopConfig);
  const popup  = window.open('', '_blank', 'width=320,height=600,scrollbars=yes,resizable=yes');
  if (!popup) {
    alert('กรุณาอนุญาต Pop-up เพื่อพิมพ์ใบเสร็จ\nPlease allow pop-ups to print receipts.');
    return;
  }
  popup.document.open();
  popup.document.write(html);
  popup.document.close();
  popup.onload = () => { popup.focus(); popup.print(); };
  setTimeout(() => { try { popup.focus(); popup.print(); } catch(e) {} }, 900);
}

// ── TEST RECEIPT DATA ─────────────────────────────────────────────────────────

const RECEIPT_TEST_ORDER = {
  order_no:         'TEST-001',
  created_at:       new Date().toISOString(),
  order_type:       'delivery',
  customer_name:    'Somchai Rakdee',
  customer_phone:   '089-123-4567',
  customer_address: 'U Baan อาคาร A ชั้น 2',
  note:             'ทดสอบหมายเหตุออเดอร์',
  subtotal:         210,
  delivery_fee:     0,
  total_price:      210,
  order_items: [
    {
      menu_name: 'Matcha Latte',
      qty: 2, unit_price: 75, note: null,
      order_item_options: [
        { choice_name: 'น้ำตาลน้อย' },
        { choice_name: 'ไม่มีน้ำแข็ง' }
      ]
    },
    {
      menu_name: 'Green Tea',
      qty: 1, unit_price: 60, note: 'Extra hot please',
      order_item_options: [{ choice_name: 'น้ำตาลปกติ' }]
    }
  ]
};

function testPrintReceipt(shopConfig) {
  printOrderReceipt(RECEIPT_TEST_ORDER, shopConfig);
}
