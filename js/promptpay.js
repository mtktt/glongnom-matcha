// PromptPay QR Generator
// Library: promptpay-qr (MIT) — loaded from CDN in index.html when payment is enabled
// This module is only activated when shop.payment_enabled === true

const PromptPay = (() => {

  // Thai PromptPay phone number for the shop — set this to the shop's registered number
  const PROMPTPAY_ID = '0000000000'; // TODO: replace with shop PromptPay number

  // Renders the payment section into a target element
  // Call this after order is inserted and order_no + total are known
  async function renderPaymentSection(containerEl, orderId, orderNo, totalAmount) {
    containerEl.innerHTML = '';

    const section = document.createElement('div');
    section.style.cssText = `
      background: #fff8f0;
      border: 1.5px solid rgba(61,28,2,0.12);
      border-radius: 16px;
      padding: 20px;
      text-align: center;
      margin-top: 16px;
    `;

    section.innerHTML = `
      <div style="font-size:1rem;font-weight:700;color:#3D1C02;margin-bottom:4px;">
        ชำระเงิน / Payment
      </div>
      <div style="font-size:0.8rem;color:#A07050;margin-bottom:16px;">
        โอนพร้อมเพย์ · ฿${totalAmount.toFixed(0)}
      </div>
      <canvas id="promptpayCanvas" style="max-width:200px;width:100%;"></canvas>
      <div style="font-size:0.75rem;color:#888;margin-top:8px;">
        สแกน QR แล้วอัพโหลดสลิป
      </div>

      <div style="margin-top:16px;">
        <label style="display:block;font-size:0.78rem;font-weight:600;color:#7A4928;margin-bottom:6px;text-align:left;">
          อัพโหลดสลิปการโอนเงิน
        </label>
        <input type="file" id="slipUpload" accept="image/*"
          style="width:100%;font-size:0.82rem;padding:8px;border:1.5px solid rgba(61,28,2,0.12);border-radius:8px;" />
        <button id="uploadSlipBtn" style="
          margin-top:10px;width:100%;padding:11px;border:none;border-radius:999px;
          background:#3D1C02;color:#FFF8F0;font-size:0.88rem;font-weight:700;cursor:pointer;
        ">
          ส่งสลิป / Upload Slip
        </button>
        <div id="slipStatus" style="font-size:0.78rem;margin-top:8px;color:#888;"></div>
      </div>
    `;

    containerEl.appendChild(section);

    // Generate QR code using promptpay-qr library
    if (window.generatePayload && window.QRCode) {
      const payload = window.generatePayload(PROMPTPAY_ID, { amount: totalAmount });
      const canvas  = document.getElementById('promptpayCanvas');
      window.QRCode.toCanvas(canvas, payload, { width: 200, margin: 2 }, err => {
        if (err) console.error('QR error:', err);
      });
    }

    // Slip upload handler
    document.getElementById('uploadSlipBtn').addEventListener('click', () =>
      uploadSlip(orderId, orderNo)
    );
  }

  async function uploadSlip(orderId, orderNo) {
    const fileInput = document.getElementById('slipUpload');
    const statusEl  = document.getElementById('slipStatus');
    const btn       = document.getElementById('uploadSlipBtn');

    if (!fileInput.files.length) {
      statusEl.textContent = 'กรุณาเลือกไฟล์สลิปก่อน';
      return;
    }

    const file     = fileInput.files[0];
    const filePath = `slips/${orderNo}_${Date.now()}.${file.name.split('.').pop()}`;

    btn.disabled    = true;
    btn.textContent = 'กำลังอัพโหลด...';
    statusEl.textContent = '';

    // Upload to Supabase Storage bucket "payment-slips"
    const { error: upErr } = await supabase.storage
      .from('payment-slips')
      .upload(filePath, file, { upsert: false });

    if (upErr) {
      statusEl.textContent = 'อัพโหลดไม่สำเร็จ: ' + upErr.message;
      btn.disabled    = false;
      btn.textContent = 'ส่งสลิป / Upload Slip';
      return;
    }

    // Get public URL and save to order row
    const { data: urlData } = supabase.storage
      .from('payment-slips')
      .getPublicUrl(filePath);

    await supabase
      .from('orders')
      .update({ payment_slip_url: urlData.publicUrl })
      .eq('id', orderId);

    statusEl.style.color = '#155724';
    statusEl.textContent = '✓ อัพโหลดสลิปเรียบร้อย! ร้านจะยืนยันการชำระเงินภายในไม่กี่นาที';
    btn.disabled    = false;
    btn.textContent = 'ส่งสลิปอีกครั้ง';
  }

  return { renderPaymentSection };
})();
