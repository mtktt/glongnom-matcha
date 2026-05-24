// ============================================================
//  Glongnom Order Site — Google Apps Script Backend (v2)
//  Sheets required: Config, Menu, Options, Orders
// ============================================================

// ────────────────────────────────────────────────────────────
//  CORS helper — wraps every response
// ────────────────────────────────────────────────────────────
function corsOutput(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// ────────────────────────────────────────────────────────────
//  SHEET BOOTSTRAP — create sheets + headers if missing
// ────────────────────────────────────────────────────────────
function bootstrapSheets() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // ── Config ──────────────────────────────────────────────
  if (!ss.getSheetByName('Config')) {
    var cfg = ss.insertSheet('Config');
    cfg.appendRow(['Key', 'Value']);
    cfg.appendRow(['shop_open',          'TRUE']);
    cfg.appendRow(['close_message',      'ขณะนี้ร้านปิดรับออเดอร์ชั่วคราวค่ะ']);
    cfg.appendRow(['line_channel_token', '']);   // Long-lived channel access token from LINE Developers Console
    cfg.appendRow(['line_user_id',       '']);   // Owner's LINE user ID for push messages
    cfg.appendRow(['shop_name',          'Glongnom']);
  }

  // ── Menu ────────────────────────────────────────────────
  if (!ss.getSheetByName('Menu')) {
    var mn = ss.insertSheet('Menu');
    mn.appendRow(['id','name_th','name_en','category','price',
                  'description_th','description_en','active','emoji_or_image']);

    var defaults = [
      // Matcha drinks
      ['m1',  'เพียวมัทฉะ',                   'Pure Matcha',                       'matcha', 59,  'มัทฉะสดชื่น ดื่มง่าย',                'Fresh and clean matcha',                        'TRUE', 'assets/pure-matcha.jpg'],
      ['m2',  'โคโคนัทมัทฉะ',                 'Coconut Matcha',                    'matcha', 69,  'มัทฉะผสมกลิ่นมะพร้าว',               'Matcha blended with coconut',                   'TRUE', 'assets/coconut-matcha.jpg'],
      ['m3',  'ฮันนี่มัทฉะ',                  'Honey Matcha',                      'matcha', 65,  'มัทฉะหวานน้ำผึ้ง',                   'Matcha sweetened with honey',                   'TRUE', 'assets/honey-matcha.jpg'],
      ['m4',  'มัทฉะลาเต้',                   'Matcha Latte',                      'matcha', 75,  'มัทฉะลาเต้คลาสสิก',                  'Classic matcha latte',                          'TRUE', 'assets/matcha-latte.jpg'],
      ['m5',  'มัทฉะเอิร์ลเกรย์ลาเต้',        'Matcha Earl Grey Latte',            'matcha', 85,  'มัทฉะผสมชาเอิร์ลเกรย์',              'Matcha blended with Earl Grey tea',             'TRUE', 'assets/matcha-earl-grey-latte.jpg'],
      ['m6',  'โอรีโอมัทฉะลาเต้',             'Oreo Matcha Latte',                 'matcha', 75,  'มัทฉะลาเต้โรยโอรีโอ',                'Matcha latte topped with Oreo crumble',         'TRUE', 'assets/oreo-matcha-latte.jpg'],
      ['m7',  'สตรอว์เบอร์รี่มัทฉะลาเต้',    'Strawberry Matcha Latte',           'matcha', 85,  'มัทฉะลาเต้ผสมสตรอว์เบอร์รี่',        'Matcha latte with strawberry',                  'TRUE', 'assets/strawberry-matcha-latte.jpg'],
      ['m8',  'สตรอว์เบอร์รี่โคลด์โฟมมัทฉะ', 'Strawberry Cold Foam Matcha Latte', 'matcha', 85,  'มัทฉะลาเต้กับโคลด์โฟมสตรอว์เบอร์รี่','Matcha latte with strawberry cold foam',         'TRUE', 'assets/strawberry-cold-foam-matcha-latte.jpg'],
      ['m9',  'บลูเบอร์รี่มัทฉะลาเต้',       'Blueberry Matcha Latte',            'matcha', 85,  'มัทฉะลาเต้ผสมบลูเบอร์รี่',           'Matcha latte with blueberry',                   'TRUE', 'assets/blueberry-matcha-latte.jpg'],
      ['m10', 'ฮันนี่มัทฉะลาเต้',            'Honey Matcha Latte',                 'matcha', 75,  'มัทฉะลาเต้ผสมน้ำผึ้ง',               'Matcha latte with honey',                       'TRUE', 'assets/honey-matcha-latte.jpg'],
      ['m11', 'คาราเมลมัทฉะลาเต้',            'Caramel Matcha Latte',               'matcha', 79,  'มัทฉะลาเต้ราดคาราเมล',               'Matcha latte with caramel drizzle',             'TRUE', 'assets/caramel-matcha-latte.jpg'],
      ['m12', 'บิสคอฟมัทฉะลาเต้',            'Biscoff Matcha Latte',               'matcha', 85,  'มัทฉะลาเต้กับบิสคอฟ',                'Matcha latte with Biscoff spread',              'TRUE', 'assets/biscoff-matcha-latte.jpg'],
      // Non-matcha drinks
      ['m13', 'โอ๊ตมิลค์โอรีโอ',             'Oat Milk Oreo',                      'drinks', 59,  'นมข้าวโอ๊ตโรยโอรีโอ',                'Oat milk with Oreo crumble',                    'TRUE', 'assets/oat-milk-oreo.jpg'],
      ['m14', 'โอ๊ตมิลค์คาราเมล',            'Oat Milk Caramel',                   'drinks', 59,  'นมข้าวโอ๊ตราดคาราเมล',               'Oat milk with caramel',                         'TRUE', 'assets/oat-milk-caramel.jpg'],
      ['m15', 'โอ๊ตมิลค์ฮันนี่',             'Oat Milk Honey',                     'drinks', 59,  'นมข้าวโอ๊ตน้ำผึ้ง',                  'Oat milk with honey',                           'TRUE', 'assets/oat-milk-honey.jpg'],
      ['m16', 'โอ๊ตมิลค์บิสคอฟ',             'Oat Milk Biscoff',                   'drinks', 69,  'นมข้าวโอ๊ตกับบิสคอฟ',                'Oat milk with Biscoff',                         'TRUE', 'assets/oat-milk-biscoff.jpg'],
      ['m17', 'สตรอว์เบอร์รี่โอ๊ตมิลค์',    'Strawberry Oat Milk',                'drinks', 69,  'นมข้าวโอ๊ตสตรอว์เบอร์รี่',            'Oat milk with strawberry',                      'TRUE', 'assets/strawberry-oat-milk.jpg'],
      ['m18', 'บลูเบอร์รี่โอ๊ตมิลค์',        'Blueberry Oat Milk',                 'drinks', 69,  'นมข้าวโอ๊ตบลูเบอร์รี่',              'Oat milk with blueberry',                       'TRUE', 'assets/blueberry-oat-milk.jpg'],
      ['m19', 'เอิร์ลเกรย์มิลค์ที',          'Earl Grey Milk Tea',                 'drinks', 75,  'ชาเอิร์ลเกรย์นม',                    'Earl Grey milk tea',                            'TRUE', 'assets/earl-grey-milk-tea.jpg'],
      ['m20', 'คิวตี้เบิร์ทเดย์มัทฉะ',       'Cutie Birthday Matcha',              'matcha', 150, 'มัทฉะสเปเชียลวันเกิด',               'Special birthday matcha set',                   'TRUE', 'assets/cutie-birthday-matcha.jpg'],
      // Rice bowls
      ['m21', 'ข้าวหมูนู่มมม',              'Pork Rice Bowl',                      'rice',   89,  'ข้าวหมูนุ่มๆ อร่อย',                 'Tender braised pork rice bowl',                 'TRUE', 'assets/moo-numm-rice.jpg'],
      ['m22', 'ข้าวเนื้อยุ่งงง',             'Pulled Beef Rice Bowl',               'rice',   99,  'ข้าวเนื้อยุ่งๆ ชุ่มซอส',             'Saucy pulled beef rice bowl',                   'TRUE', 'assets/beef-numm-rice.jpg']
    ];
    defaults.forEach(function(row) { mn.appendRow(row); });
  }

  // ── Options ─────────────────────────────────────────────
  if (!ss.getSheetByName('Options')) {
    var op = ss.insertSheet('Options');
    op.appendRow(['group_id','group_name_th','group_name_en',
                  'option_name_th','option_name_en','price_modifier','is_required','active']);

    var optDefaults = [
      // Matcha grade — applies to category=matcha items
      ['matcha_grade','เลือกมัทฉะ','Matcha Grade','Medium grade (umami/strength)','Medium grade (umami/strength)',0,'TRUE','TRUE'],
      ['matcha_grade','เลือกมัทฉะ','Matcha Grade','High grade (umami/smooth/aroma) +10บาท','High grade (umami/smooth/aroma) +10 THB',10,'TRUE','TRUE'],
      // Sweetness — drinks only
      ['sweetness','ความหวาน','Sweetness','0% (ไม่ใส่น้ำตาล)','0% (No syrup)',0,'TRUE','TRUE'],
      ['sweetness','ความหวาน','Sweetness','25%','25%',0,'TRUE','TRUE'],
      ['sweetness','ความหวาน','Sweetness','50%','50%',0,'TRUE','TRUE'],
      ['sweetness','ความหวาน','Sweetness','100%','100%',0,'TRUE','TRUE'],
      ['sweetness','ความหวาน','Sweetness','150%','150%',0,'TRUE','TRUE'],
      // Matcha serving style — matcha items only
      ['matcha_sep','แยกมัทฉะ','Matcha Serving','แยกมัทฉะใส่ถ้วย','Matcha on the side',0,'TRUE','TRUE'],
      ['matcha_sep','แยกมัทฉะ','Matcha Serving','เทมัทฉะลงแก้ว','Mix matcha into drink',0,'TRUE','TRUE'],
      // Ice
      ['ice_sep','น้ำแข็ง','Ice','แยกน้ำแข็งใส่ถุงซิป','Ice on the side (zip bag)',0,'TRUE','TRUE'],
      ['ice_sep','น้ำแข็ง','Ice','ใส่น้ำแข็งลงแก้วพร้อมดื่ม','Ice in the cup',0,'TRUE','TRUE'],
      // Rice sauce
      ['rice_sauce','เลือกซอส','Sauce','Garlic shoyu','Garlic shoyu',0,'TRUE','TRUE'],
      ['rice_sauce','เลือกซอส','Sauce','BBQ sauce','BBQ sauce',0,'TRUE','TRUE'],
      // Rice add-ons (not required)
      ['rice_extra','เพิ่มเติม','Add-ons','เพิ่มสาหร่ายโรยข้าว','Add seaweed',10,'FALSE','TRUE'],
      ['rice_extra','เพิ่มเติม','Add-ons','เพิ่มซุปมิโซะ','Add miso soup',10,'FALSE','TRUE'],
      ['rice_extra','เพิ่มเติม','Add-ons','เพิ่มสลัด','Add salad',10,'FALSE','TRUE']
    ];
    optDefaults.forEach(function(row) { op.appendRow(row); });
  }

  // ── Orders ──────────────────────────────────────────────
  if (!ss.getSheetByName('Orders')) {
    var ord = ss.insertSheet('Orders');
    ord.appendRow([
      'timestamp','order_id','customer_name','phone',
      'address','items_json','subtotal','total',
      'status','line_notified'
    ]);
  }
}

// ────────────────────────────────────────────────────────────
//  READ CONFIG
// ────────────────────────────────────────────────────────────
function getConfig() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('Config');
  if (!sheet) return {};

  var rows = sheet.getDataRange().getValues();
  var cfg  = {};
  for (var i = 1; i < rows.length; i++) {
    var key = String(rows[i][0]).trim();
    var val = rows[i][1];
    if (key) cfg[key] = val;
  }
  return cfg;
}

// ────────────────────────────────────────────────────────────
//  READ MENU — returns ALL rows (active AND inactive)
//  Frontend decides whether to show sold-out items as grayed out
// ────────────────────────────────────────────────────────────
function getMenuData() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('Menu');
  if (!sheet) return [];

  var rows   = sheet.getDataRange().getValues();
  var header = rows.shift();

  var col = {};
  header.forEach(function(h, i) { col[String(h).trim()] = i; });

  return rows.map(function(row) {
    return {
      id:             String(row[col['id']]             || '').trim(),
      name_th:        String(row[col['name_th']]        || '').trim(),
      name_en:        String(row[col['name_en']]        || '').trim(),
      category:       String(row[col['category']]       || '').trim().toLowerCase(),
      price:          Number(row[col['price']])          || 0,
      description_th: String(row[col['description_th']] || '').trim(),
      description_en: String(row[col['description_en']] || '').trim(),
      active:         String(row[col['active']]).trim().toUpperCase() !== 'FALSE',
      emoji_or_image: String(row[col['emoji_or_image']] || '').trim()
    };
  });
}

// ────────────────────────────────────────────────────────────
//  READ OPTIONS — collapsed into option groups
//  Inactive options (active = FALSE) are filtered out before returning
// ────────────────────────────────────────────────────────────
function getOptionsData() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('Options');
  if (!sheet) return [];

  var rows   = sheet.getDataRange().getValues();
  var header = rows.shift();

  var col = {};
  header.forEach(function(h, i) { col[String(h).trim()] = i; });

  var groupMap = {};
  var groupOrder = [];

  rows.forEach(function(row) {
    var gid = String(row[col['group_id']] || '').trim();
    if (!gid) return;

    // Filter out inactive options
    var rawActive = col['active'] !== undefined ? row[col['active']] : 'TRUE';
    var isActive  = (rawActive === true || String(rawActive).trim().toUpperCase() === 'TRUE');
    if (!isActive) return;

    if (!groupMap[gid]) {
      groupMap[gid] = {
        group_id:      gid,
        group_name_th: String(row[col['group_name_th']] || '').trim(),
        group_name_en: String(row[col['group_name_en']] || '').trim(),
        is_required:   String(row[col['is_required']]).trim().toUpperCase() !== 'FALSE',
        options:       []
      };
      groupOrder.push(gid);
    }

    groupMap[gid].options.push({
      name_th:        String(row[col['option_name_th']] || '').trim(),
      name_en:        String(row[col['option_name_en']] || '').trim(),
      price_modifier: Number(row[col['price_modifier']]) || 0
    });
  });

  return groupOrder.map(function(gid) { return groupMap[gid]; });
}

// ────────────────────────────────────────────────────────────
//  doGet — return shop status + full menu + options
//          OR dashboard analytics (action=dashboard)
// ────────────────────────────────────────────────────────────
function doGet(e) {
  bootstrapSheets();
  var params = (e && e.parameter) ? e.parameter : {};

  if (params.action === 'dashboard') {
    return corsOutput(getDashboardData(params));
  }

  var cfg      = getConfig();
  var rawOpen  = cfg['shop_open'];
  var shopOpen = (rawOpen === true || String(rawOpen).trim().toUpperCase() === 'TRUE');

  var payload = {
    shop_open:     shopOpen,
    close_message: String(cfg['close_message'] || 'ร้านปิดรับออเดอร์ชั่วคราวค่ะ').trim(),
    shop_name:     String(cfg['shop_name']     || 'Glongnom').trim(),
    menu:          getMenuData(),
    options:       getOptionsData()
  };

  return corsOutput(payload);
}

// ────────────────────────────────────────────────────────────
//  DASHBOARD DATA — aggregated analytics from Orders sheet
// ────────────────────────────────────────────────────────────
function getDashboardData(params) {
  var tz       = Session.getScriptTimeZone();
  var now      = new Date();
  var period   = String(params.period || 'today').trim();
  var fromISO  = String(params.from   || '').trim();
  var toISO    = String(params.to     || '').trim();
  var todayStr = Utilities.formatDate(now, tz, 'yyyy-MM-dd');

  // Resolve date range
  if (period === 'today') {
    fromISO = todayStr; toISO = todayStr;
  } else if (period === 'week') {
    var dw = new Date(now); dw.setDate(now.getDate() - 6);
    fromISO = Utilities.formatDate(dw, tz, 'yyyy-MM-dd'); toISO = todayStr;
  } else if (period === 'month') {
    var dm = new Date(now.getFullYear(), now.getMonth(), 1);
    fromISO = Utilities.formatDate(dm, tz, 'yyyy-MM-dd'); toISO = todayStr;
  } else {
    if (!fromISO) fromISO = todayStr;
    if (!toISO)   toISO   = todayStr;
  }

  // Previous period (same span, immediately before)
  var msFrom   = new Date(fromISO + 'T00:00:00').getTime();
  var msTo     = new Date(toISO   + 'T00:00:00').getTime();
  var spanMs   = msTo - msFrom + 86400000;
  var spanDays = Math.round(spanMs / 86400000);
  var prevToStr   = Utilities.formatDate(new Date(msFrom - 86400000), tz, 'yyyy-MM-dd');
  var prevFromStr = Utilities.formatDate(new Date(msFrom - spanMs),   tz, 'yyyy-MM-dd');

  var ss       = SpreadsheetApp.getActiveSpreadsheet();
  var ordSheet = ss.getSheetByName('Orders');
  if (!ordSheet) return _emptyDash(fromISO, toISO, period);

  var raw = ordSheet.getDataRange().getValues();
  if (raw.length < 2) return _emptyDash(fromISO, toISO, period);

  var header = raw[0];
  var col    = {};
  header.forEach(function(h, i) { col[String(h).trim().toLowerCase()] = i; });

  // Category lookup from Menu sheet (by id and name)
  var catById = {}, catByName = {};
  var menuSheet = ss.getSheetByName('Menu');
  if (menuSheet) {
    var mRaw = menuSheet.getDataRange().getValues();
    var mc   = {};
    mRaw[0].forEach(function(h, i) { mc[String(h).trim()] = i; });
    mRaw.slice(1).forEach(function(row) {
      var id  = String(row[mc['id']]      || '').trim();
      var en  = String(row[mc['name_en']] || '').trim().toLowerCase();
      var th  = String(row[mc['name_th']] || '').trim().toLowerCase();
      var cat = String(row[mc['category']]|| '').trim().toLowerCase();
      if (id)  catById[id]    = cat;
      if (en)  catByName[en]  = cat;
      if (th)  catByName[th]  = cat;
    });
  }

  var rows = raw.slice(1).filter(function(r) {
    return r[col['order_id']] && r[col['timestamp']];
  });

  function parseDate(r) {
    var ts = r[col['timestamp']];
    if (ts instanceof Date) {
      return {
        date: Utilities.formatDate(ts, tz, 'yyyy-MM-dd'),
        hour: Utilities.formatDate(ts, tz, 'HH'),
        dow:  ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][ts.getDay()]
      };
    }
    var s = String(ts || '');
    var d = new Date(s);
    return {
      date: s.substring(0, 10),
      hour: (s.substring(11, 13) || '00'),
      dow:  isNaN(d.getTime()) ? 'Mon' : ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d.getDay()]
    };
  }

  function inRange(r, from, to) {
    var d = parseDate(r).date;
    return d >= from && d <= to;
  }

  function agg(rs) {
    var rev = 0;
    var orderMap = {}, custMap = {}, sellerMap = {}, optMap = {};
    var hourMap  = {}, dateMap  = {}, heatMap  = {};

    rs.forEach(function(r) {
      var oid   = String(r[col['order_id']] || '').trim();
      var total = parseFloat(r[col['total']]) || parseFloat(r[col['subtotal']]) || 0;
      var cust  = String(r[col['customer_name']] || '').trim();
      var dh    = parseDate(r);
      if (!oid) return;

      rev += total;
      if (cust) custMap[cust] = (custMap[cust] || 0) + 1;

      if (!orderMap[oid]) {
        orderMap[oid] = { id: oid, customer: cust, total: total, time: dh.hour + ':00', items: [] };
      }

      // Parse items JSON
      var items = [];
      try { items = JSON.parse(String(r[col['items_json']] || '[]')); } catch(ex) {}
      items.forEach(function(it) {
        var iId     = String(it.id    || '').trim();
        var iName   = String(it.name_en || it.name || '').trim();
        var iNameTh = String(it.name_th || iName).trim();
        var iQty    = parseInt(it.qty) || 1;
        var iSub    = parseFloat(it.subtotal) || 0;
        var iOpts   = String(it.optionsText || '').trim();
        var iCat    = catById[iId] || catByName[iName.toLowerCase()] || catByName[iNameTh.toLowerCase()] || 'other';

        orderMap[oid].items.push((iNameTh || iName) + (iQty > 1 ? ' ×' + iQty : ''));

        var sk = iName || iNameTh;
        if (sk) {
          if (!sellerMap[sk]) sellerMap[sk] = { name: iName || iNameTh, name_th: iNameTh, category: iCat, qty: 0, revenue: 0 };
          sellerMap[sk].qty     += iQty;
          sellerMap[sk].revenue += iSub;
        }

        if (iOpts) {
          iOpts.split(' | ').forEach(function(seg) {
            var ps  = seg.split(': ');
            if (ps.length < 2) return;
            var lbl = ps[0].trim();
            var val = ps.slice(1).join(': ').trim();
            var p   = val.indexOf('(');
            if (p > 0) val = val.substring(0, p).trim();
            if (!lbl || !val) return;
            if (!optMap[lbl]) optMap[lbl] = {};
            optMap[lbl][val] = (optMap[lbl][val] || 0) + iQty;
          });
        }
      });

      var hk = dh.hour.padStart(2, '0');
      var dk = dh.date;
      if (!hourMap[hk]) hourMap[hk] = { rev: 0, orders: 0, seen: {} };
      hourMap[hk].rev += total;
      if (!hourMap[hk].seen[oid]) { hourMap[hk].seen[oid] = 1; hourMap[hk].orders++; }

      if (!dateMap[dk]) dateMap[dk] = { rev: 0, orders: 0, seen: {} };
      dateMap[dk].rev += total;
      if (!dateMap[dk].seen[oid]) { dateMap[dk].seen[oid] = 1; dateMap[dk].orders++; }

      var heatKey = dh.dow + '_' + hk;
      if (!heatMap[heatKey]) heatMap[heatKey] = { rev: 0, orders: 0 };
      heatMap[heatKey].rev    += total;
      heatMap[heatKey].orders += 1;
    });

    var orderCount = Object.keys(orderMap).length;
    var custCount  = Object.keys(custMap).length;

    var recent = Object.values(orderMap)
      .sort(function(a, b) { return a.id > b.id ? -1 : 1; })
      .slice(0, 20)
      .map(function(o) {
        return { id: o.id, customer: o.customer || '-', items: o.items.join(', '), total: Math.round(o.total), time: o.time };
      });

    var sellers = Object.values(sellerMap)
      .sort(function(a, b) { return b.revenue - a.revenue; })
      .slice(0, 10);

    var options = Object.keys(optMap).map(function(lbl) {
      var counts = optMap[lbl];
      var total2 = Object.values(counts).reduce(function(s, c) { return s + c; }, 0) || 1;
      var segs   = Object.keys(counts).map(function(v) {
        return { name: v, count: counts[v], pct: Math.round(counts[v] / total2 * 100) };
      }).sort(function(a, b) { return b.count - a.count; });
      return { label: lbl, segs: segs };
    });

    var topCust = Object.keys(custMap)
      .map(function(n) { return { name: n, orders: custMap[n] }; })
      .sort(function(a, b) { return b.orders - a.orders; })
      .slice(0, 8);

    return { revenue: Math.round(rev), orders: orderCount, customers: custCount,
             avg_basket: orderCount > 0 ? Math.round(rev / orderCount) : 0,
             sellers: sellers, recent: recent, top_customers: topCust, options: options,
             hourMap: hourMap, dateMap: dateMap, heatMap: heatMap };
  }

  var cur  = agg(rows.filter(function(r) { return inRange(r, fromISO, toISO); }));
  var prev = agg(rows.filter(function(r) { return inRange(r, prevFromStr, prevToStr); }));

  // Today data (for hours-of-day card — always today regardless of period)
  var todayData = (fromISO === todayStr && toISO === todayStr) ? cur
                : agg(rows.filter(function(r) { return inRange(r, todayStr, todayStr); }));

  // Last-7-day data for heatmap
  var last7Start = Utilities.formatDate(new Date(now.getTime() - 6 * 86400000), tz, 'yyyy-MM-dd');
  var last7Data  = (fromISO === last7Start && toISO === todayStr) ? cur
                 : agg(rows.filter(function(r) { return inRange(r, last7Start, todayStr); }));

  // Time series
  var isHourly = (fromISO === toISO);
  var series = [], prevSeries = [];

  if (isHourly) {
    for (var h = 8; h <= 22; h++) {
      var hk2 = String(h).padStart(2, '0');
      series.push({ label: hk2 + ':00', revenue: (cur.hourMap[hk2] || {}).rev || 0, orders: (cur.hourMap[hk2] || {}).orders || 0 });
      prevSeries.push({ label: hk2 + ':00', revenue: (prev.hourMap[hk2] || {}).rev || 0, orders: (prev.hourMap[hk2] || {}).orders || 0 });
    }
  } else {
    var dt = new Date(fromISO + 'T12:00:00');
    var endDt = new Date(toISO + 'T12:00:00');
    while (dt <= endDt) {
      var dKey   = Utilities.formatDate(dt, tz, 'yyyy-MM-dd');
      var label  = Utilities.formatDate(dt, tz, 'MM/dd');
      var prevDt = new Date(dt.getTime() - spanDays * 86400000);
      var pdKey  = Utilities.formatDate(prevDt, tz, 'yyyy-MM-dd');
      series.push({ label: label, revenue: (cur.dateMap[dKey] || {}).rev || 0, orders: (cur.dateMap[dKey] || {}).orders || 0 });
      prevSeries.push({ label: label, revenue: (prev.dateMap[pdKey] || {}).rev || 0, orders: (prev.dateMap[pdKey] || {}).orders || 0 });
      dt.setDate(dt.getDate() + 1);
    }
  }

  // Today hourly for period-of-day card
  var todayHourly = [];
  for (var h3 = 8; h3 <= 22; h3++) {
    var hk3 = String(h3).padStart(2, '0');
    todayHourly.push({ h: h3, label: hk3 + ':00', revenue: (todayData.hourMap[hk3] || {}).rev || 0, orders: (todayData.hourMap[hk3] || {}).orders || 0 });
  }

  // Heatmap (last 7 days, day-of-week × hour)
  var heatDays  = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  var heatHours = [];
  for (var hh = 8; hh <= 21; hh++) heatHours.push(hh);
  var maxHeatRev = 1;
  heatDays.forEach(function(day) {
    heatHours.forEach(function(h4) {
      var k = day + '_' + String(h4).padStart(2, '0');
      var b = last7Data.heatMap[k] || { rev: 0 };
      if (b.rev > maxHeatRev) maxHeatRev = b.rev;
    });
  });
  var heatData = heatDays.map(function(day) {
    return {
      day: day,
      cells: heatHours.map(function(h4) {
        var k = day + '_' + String(h4).padStart(2, '0');
        var b = last7Data.heatMap[k] || { rev: 0, orders: 0 };
        var val = b.rev > 0 ? Math.max(1, Math.min(6, Math.ceil(b.rev / maxHeatRev * 6))) : 0;
        return { h: h4, val: val, orders: b.orders };
      })
    };
  });

  // 7-day basket trend
  var basketTrend = [];
  for (var bd = 6; bd >= 0; bd--) {
    var bDStr = Utilities.formatDate(new Date(now.getTime() - bd * 86400000), tz, 'yyyy-MM-dd');
    var bBuck = cur.dateMap[bDStr] || last7Data.dateMap[bDStr] || null;
    basketTrend.push(bBuck && bBuck.orders > 0 ? Math.round(bBuck.rev / bBuck.orders) : 0);
  }

  return {
    revenue: cur.revenue, prev_revenue: prev.revenue,
    orders:  cur.orders,  prev_orders:  prev.orders,
    avg_basket: cur.avg_basket, prev_avg_basket: prev.avg_basket,
    customers:  cur.customers,  prev_customers:  prev.customers,
    sellers:     cur.sellers,
    recent:      cur.recent,
    top_customers: cur.top_customers,
    options:     cur.options,
    series:      series,
    prev_series: prevSeries,
    today_hourly: todayHourly,
    heatmap: { days: heatDays, hours: heatHours, data: heatData },
    basket_trend: basketTrend,
    period: period, from: fromISO, to: toISO,
    generated_at: Utilities.formatDate(now, tz, 'yyyy-MM-dd HH:mm:ss')
  };
}

function _emptyDash(from, to, period) {
  var hours = [];
  for (var h = 8; h <= 22; h++) {
    hours.push({ label: String(h).padStart(2,'0') + ':00', revenue: 0, orders: 0 });
  }
  return {
    revenue: 0, prev_revenue: 0, orders: 0, prev_orders: 0,
    avg_basket: 0, prev_avg_basket: 0, customers: 0, prev_customers: 0,
    sellers: [], recent: [], top_customers: [], options: [],
    series: hours, prev_series: hours, today_hourly: hours,
    heatmap: { days: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'], hours: [8,9,10,11,12,13,14,15,16,17,18,19,20,21], data: [] },
    basket_trend: [0,0,0,0,0,0,0],
    period: period, from: from, to: to, generated_at: ''
  };
}

// ────────────────────────────────────────────────────────────
//  doPost — receive order JSON, validate, save, notify Line
// ────────────────────────────────────────────────────────────
function doPost(e) {
  try {
    bootstrapSheets();

    var payload = (e.postData && e.postData.contents) ? e.postData.contents : '{}';
    var order   = JSON.parse(payload);

    // Validation
    if (!order.customer_name)
      throw new Error('customer_name is required');
    if (!order.phone)
      throw new Error('phone is required');
    if (!order.address)
      throw new Error('address is required');
    if (!Array.isArray(order.items) || order.items.length === 0)
      throw new Error('items array is empty');

    // Generate order ID: ORD-YYYYMMDD-XXXX
    var now      = new Date();
    var datePart = Utilities.formatDate(now, Session.getScriptTimeZone(), 'yyyyMMdd');
    var rand     = Math.floor(1000 + Math.random() * 9000);
    var orderId  = 'ORD-' + datePart + '-' + rand;

    // Compute totals
    var total = order.items.reduce(function(s, it) {
      return s + (Number(it.subtotal) || 0);
    }, 0);

    // Save to sheet
    saveOrder(order, orderId, now, total);

    // Line Messaging API
    var lineNotified = sendLineMessage(order, orderId, total) ? 'yes' : 'no';

    // Update line_notified status in the row we just wrote
    updateLineNotified(orderId, lineNotified);

    return corsOutput({ status: 'ok', order_id: orderId, total: total });

  } catch (err) {
    return corsOutput({ status: 'error', message: err.message });
  }
}

// ────────────────────────────────────────────────────────────
//  SAVE ORDER
// ────────────────────────────────────────────────────────────
function saveOrder(order, orderId, now, total) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('Orders');

  var tsStr = Utilities.formatDate(now, Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');

  sheet.appendRow([
    tsStr,
    orderId,
    order.customer_name,
    order.phone,
    order.address,
    JSON.stringify(order.items),
    total,   // subtotal == total (no delivery fee tier yet)
    total,
    'new',
    'pending'
  ]);
}

// ────────────────────────────────────────────────────────────
//  UPDATE line_notified COLUMN after notify attempt
// ────────────────────────────────────────────────────────────
function updateLineNotified(orderId, value) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName('Orders');
  var data  = sheet.getDataRange().getValues();
  var header = data[0];
  var colOrderId       = header.indexOf('order_id');
  var colLineNotified  = header.indexOf('line_notified');
  if (colOrderId < 0 || colLineNotified < 0) return;

  for (var i = 1; i < data.length; i++) {
    if (String(data[i][colOrderId]).trim() === orderId) {
      sheet.getRange(i + 1, colLineNotified + 1).setValue(value);
      return;
    }
  }
}

// ────────────────────────────────────────────────────────────
//  SEND LINE MESSAGE (Line Messaging API — push message)
//  Requires: line_channel_token and line_user_id in Config sheet
// ────────────────────────────────────────────────────────────
function sendLineMessage(order, orderId, total) {
  var cfg    = getConfig();
  var token  = String(cfg['line_channel_token'] || '').trim();
  var rawIds = String(cfg['line_user_id']       || '').trim();
  if (!token || !rawIds) return false;

  var userIds = rawIds.split(',').map(function(id) { return id.trim(); }).filter(function(id) { return id; });
  if (userIds.length === 0) return false;

  var lines = [];
  lines.push('📥 ออเดอร์ใหม่ — ' + orderId);
  lines.push('────────────────');
  lines.push('👤 ' + (order.customer_name || '-'));
  lines.push('📞 ' + (order.phone         || '-'));
  lines.push('📍 ' + (order.address       || '-'));
  lines.push('');
  lines.push('รายการ:');

  order.items.forEach(function(item, idx) {
    lines.push((idx + 1) + '. ' + (item.name_th || item.name || '-') + ' x' + item.qty + ' = ' + item.subtotal + '฿');
    if (item.optionsText) {
      item.optionsText.split(' | ').forEach(function(opt) {
        var parts = opt.split(': ');
        var label = parts[0] || '';
        var val   = parts.slice(1).join(': ');
        var paren = val.indexOf('(');
        if (paren > 0) val = val.substring(0, paren);
        val = val.trim().split(/\s+/).slice(0, 3).join(' ');
        lines.push('   • ' + label + ': ' + val);
      });
    }
    if (item.note) lines.push('   หมายเหตุ: ' + item.note);
  });

  lines.push('');
  lines.push('💰 ยอดรวม: ' + total + ' บาท');

  var msgText = lines.join('\n');

  userIds.forEach(function(uid) {
    UrlFetchApp.fetch('https://api.line.me/v2/bot/message/push', {
      method:             'post',
      contentType:        'application/json',
      headers:            { 'Authorization': 'Bearer ' + token },
      payload:            JSON.stringify({ to: uid, messages: [{ type: 'text', text: msgText }] }),
      muteHttpExceptions: true
    });
  });

  return true;
}
