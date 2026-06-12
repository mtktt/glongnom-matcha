-- ============================================================
-- Glongnom POS — Menu Seed Data
-- Source: menu.csv + options.csv (latest version from Google Sheets)
-- Run this AFTER 001_initial_schema.sql
-- ============================================================

-- ============================================================
-- MENU ITEMS
-- ============================================================

-- Matcha items (13 items)
INSERT INTO menus (shop_id, category_id, name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
SELECT
  s.id,
  c.id,
  v.name, v.name_th, v.description, v.description_th,
  v.base_price, v.image_url, v.is_active, v.sort_order
FROM shops s
CROSS JOIN categories c
CROSS JOIN (VALUES
  ('Pure Matcha',                    'เพียวมัทฉะ',              'Clean matcha with mineral water',           'มัทฉะและน้ำแร่สดชื่น ดื่มง่าย',                           69,  'assets/pure-matcha.jpg',                          true,  1),
  ('Coconut Matcha',                 'มัทฉะมะพร้าว',            'Matcha blended with pure coconut',          'มัทฉะผสมน้ำมะพร้าวแท้ หอมหวานสดชื่น',                    69,  'assets/coconut-matcha.jpg',                       true,  2),
  ('Honey Matcha',                   'มัทฉะน้ำผึ้ง',            'Matcha sweetened with natural honey',       'มัทฉะน้ำผึ้งธรรมชาติ หวานสดชื่น',                        65,  'assets/honey-matcha.jpg',                         true,  3),
  ('Matcha Latte',                   'มัทฉะลาเต้',              'Matcha blended with oat milk',              'มัทฉะนมโอ๊ตหอมมันนัว ทานง่าย',                            75,  'assets/matcha-latte.jpg',                         true,  4),
  ('Matcha Earl Grey Latte',         'มัทฉะเอิร์ลเกรย์ลาเต้',  'Matcha blended with Earl Grey milk tea',    'มัทฉะผสมชาเอิร์ลเกรย์ตุ๋นนมโอ๊ต หอมกลมกล่อม',           85,  'assets/matcha-earl-grey-latte.jpg',               true,  5),
  ('Oreo Matcha Latte',              'โอรีโอมัทฉะลาเต้',        'Matcha latte with Oreo crumble',            'มัทฉะลาเต้ผสมโอรีโอ้กรุบกรอบ',                            75,  'assets/oreo-matcha-latte.jpg',                    true,  6),
  ('Strawberry Matcha Latte',        'สตรอว์เบอร์รี่มัทฉะลาเต้','Matcha latte with strawberry sauce',        'มัทฉะลาเต้ผสมซอสสตรอว์เบอร์รี่สด มีเนื้อให้เคี้ยวหวานอมเปรี้ยว', 85, 'assets/strawberry-matcha-latte.jpg',    true,  7),
  ('Strawberry Cold Foam Matcha Latte','สตรอว์เบอร์รี่โคลด์โฟมมัทฉะ','Matcha latte with strawberry cold foam','มัทฉะลาเต้กับโคลด์โฟมสตรอว์เบอร์รี่',                 85,  'assets/strawberry-cold-foam-matcha-latte.jpg',    false, 8),
  ('Blueberry Matcha Latte',         'บลูเบอร์รี่มัทฉะลาเต้',   'Matcha latte with blueberry sauce',         'มัทฉะลาเต้ผสมซอสบลูเบอร์รี่ หวานอมเปรี้ยว',              85,  'assets/blueberry-matcha-latte.jpg',               true,  9),
  ('Honey Matcha Latte',             'ฮันนี่มัทฉะลาเต้',        'Matcha latte with natural honey',           'มัทฉะลาเต้ผสมน้ำผึ้งธรรมชาติแท้',                        75,  'assets/honey-matcha-latte.jpg',                   true,  10),
  ('Caramel Matcha Latte',           'คาราเมลมัทฉะลาเต้',       'Matcha latte with caramel sauce',           'มัทฉะลาเต้ผสมซอสคาราเมล หวานมันเติมพลัง',                79,  'assets/caramel-matcha-latte.jpg',                 true,  11),
  ('Biscoff Matcha Latte',           'บิสคอฟมัทฉะลาเต้',        'Matcha latte with Biscoff spread',          'มัทฉะลาเต้กับคุกกี้บิสคอฟเข้มข้น',                       85,  'assets/biscoff-matcha-latte.jpg',                 true,  12),
  ('Cutie Birthday Matcha',          'คิวตี้เบิร์ทเดย์มัทฉะ',   'Special birthday matcha set',               'มัทฉะชุดพิเศษสำหรับวันเกิด',                              150, 'assets/cutie-birthday-matcha.jpg',                true,  13)
) AS v(name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
WHERE s.branch_code = 'GLN-01'
  AND c.name = 'Matcha'
  AND c.shop_id = s.id;

-- Drinks items (7 items)
INSERT INTO menus (shop_id, category_id, name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
SELECT
  s.id,
  c.id,
  v.name, v.name_th, v.description, v.description_th,
  v.base_price, v.image_url, v.is_active, v.sort_order
FROM shops s
CROSS JOIN categories c
CROSS JOIN (VALUES
  ('Oat Milk Oreo',      'นมโอ๊ตโอรีโอ',         'Oat milk with Oreo crumble',    'นมโอ๊ตโอรีโอกรุบกรอบ',                    59, 'assets/oat-milk-oreo.jpg',         true, 1),
  ('Oat Milk Caramel',   'นมโอ๊ตคาราเมล',         'Oat milk with caramel sauce',   'นมโอ๊ตผสมซอสคาราเมล',                     59, 'assets/oat-milk-caramel.jpg',      true, 2),
  ('Oat Milk Honey',     'นมโอ๊ตน้ำผึ้ง',         'Oat milk with natural honey',   'นมโอ๊ตน้ำผึ้งแท้เดือน 5',                 59, 'assets/oat-milk-honey.jpg',        true, 3),
  ('Oat Milk Biscoff',   'นมโอ๊ตบิสคอฟ',          'Oat milk with Biscoff spread',  'นมโอ๊ตผสมคุกกี้บิสคอฟเข้มข้น',            69, 'assets/oat-milk-biscoff.jpg',      true, 4),
  ('Strawberry Oat Milk','สตรอว์เบอร์รี่นมโอ๊ต',  'Oat milk with strawberry sauce','นมโอ๊ตสตรอว์เบอร์รี่ซอส มีเนื้อให้เคี้ยว', 69, 'assets/strawberry-oat-milk.jpg',   true, 5),
  ('Blueberry Oat Milk', 'บลูเบอร์รี่นมโอ๊ต',    'Oat milk with blueberry sauce', 'นมโอ๊ตบลูเบอร์รี่ซอส',                    69, 'assets/blueberry-oat-milk.jpg',    true, 6),
  ('Earl Grey Milk Tea',  'ชานมเอิร์ลเกรย์',      'Earl Grey milk tea',            'ชาเอิร์ลเกรย์ตุ๋นนมโอ๊ต',                 75, 'assets/earl-grey-milk-tea.jpg',    true, 7)
) AS v(name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
WHERE s.branch_code = 'GLN-01'
  AND c.name = 'Drinks'
  AND c.shop_id = s.id;

-- Rice items (2 items)
INSERT INTO menus (shop_id, category_id, name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
SELECT
  s.id,
  c.id,
  v.name, v.name_th, v.description, v.description_th,
  v.base_price, v.image_url, v.is_active, v.sort_order
FROM shops s
CROSS JOIN categories c
CROSS JOIN (VALUES
  ('Grilled Pork Rice Bowl','ข้าวหมูนู่มมม', 'Tender braised pork rice bowl',          'ข้าวหมูนุ่มๆ อร่อยยยยยย',              100, 'assets/moo-numm-rice.jpg',  true, 1),
  ('Grilled Beef Rice Bowl','ข้าวเนื้อยุ่งงง','Yakiniku saucy beef rice bowl',           'ข้าวเนื้อย่างชุ่มซอส สไตล์ yakiniku',  100, 'assets/beef-numm-rice.jpg', true, 2)
) AS v(name, name_th, description, description_th, base_price, image_url, is_active, sort_order)
WHERE s.branch_code = 'GLN-01'
  AND c.name = 'Rice'
  AND c.shop_id = s.id;

-- ============================================================
-- OPTION GROUPS
-- Each menu item gets its own group rows (per-item schema)
-- ============================================================

-- ── Matcha items: Matcha Grade (sort 1) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Matcha Grade', 'เลือกมัทฉะ', true, 1
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Matcha';

-- ── Matcha items: Sweetness (sort 2) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Sweetness', 'ความหวาน', true, 2
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Matcha';

-- ── Matcha items: Matcha Serving (sort 3) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Matcha Serving', 'แยกมัทฉะ', true, 3
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Matcha';

-- ── Matcha items: Ice (sort 4) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Ice', 'น้ำแข็ง', true, 4
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Matcha';

-- ── Drinks items: Sweetness (sort 1) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Sweetness', 'ความหวาน', true, 1
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Drinks';

-- ── Drinks items: Ice (sort 2) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Ice', 'น้ำแข็ง', true, 2
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Drinks';

-- ── Rice items: Sauce (sort 1) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Sauce', 'เลือกซอส', true, 1
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Rice';

-- ── Rice items: Add-ons (sort 2, NOT required) ──
INSERT INTO option_groups (menu_id, name, name_th, is_required, sort_order)
SELECT m.id, 'Add-ons', 'เพิ่มเติม', false, 2
FROM menus m
JOIN categories c ON c.id = m.category_id
WHERE c.name = 'Rice';

-- ============================================================
-- OPTION CHOICES
-- Insert choices for every group of each type in one statement
-- ============================================================

-- ── Matcha Grade choices ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('Medium grade (umami/strength)', 'Medium grade (umami/strength)',  0,  1),
  ('High grade (umami/smooth/aroma)','High grade (umami/smooth/aroma)', 10, 2)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Matcha Grade';

-- ── Sweetness choices (applies to both Matcha and Drinks groups) ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('0% (No syrup)', '0% (ไม่ใส่น้ำตาล)', 0, 1),
  ('25%',           '25%',                 0, 2),
  ('50%',           '50%',                 0, 3),
  ('100%',          '100%',                0, 4),
  ('150%',          '150%',                0, 5)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Sweetness';

-- ── Matcha Serving choices ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('Matcha separated in cup', 'แยกมัทฉะใส่ถ้วย', 0, 1),
  ('Mix matcha into drink',   'เทมัทฉะลงแก้ว',   0, 2)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Matcha Serving';

-- ── Ice choices (applies to both Matcha and Drinks groups) ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('Ice separated (zip bag)', 'แยกน้ำแข็งใส่ถุงซิป',    0, 1),
  ('Ice in the cup',          'ใส่น้ำแข็งลงแก้วพร้อมดื่ม', 0, 2)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Ice';

-- ── Sauce choices (Rice only) ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('Garlic shoyu', 'Garlic shoyu', 0, 1),
  ('BBQ sauce',    'BBQ sauce',    0, 2)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Sauce';

-- ── Add-ons choices (Rice only, not required) ──
INSERT INTO option_choices (group_id, name, name_th, additional_price, sort_order)
SELECT g.id, v.name, v.name_th, v.additional_price, v.sort_order
FROM option_groups g
CROSS JOIN (VALUES
  ('Add seaweed',  'เพิ่มสาหร่ายโรยข้าว', 10, 1),
  ('Add miso soup','เพิ่มซุปมิโซะ',        10, 2),
  ('Add salad',    'เพิ่มสลัด',            10, 3)
) AS v(name, name_th, additional_price, sort_order)
WHERE g.name = 'Add-ons';

-- ============================================================
-- VERIFY — run each line separately in SQL Editor to confirm
-- ============================================================
-- SELECT COUNT(*) FROM menus;          -- expect 22
-- SELECT COUNT(*) FROM option_groups;  -- expect 70
-- SELECT COUNT(*) FROM option_choices; -- expect 202
