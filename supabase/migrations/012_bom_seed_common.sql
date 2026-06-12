-- ============================================================
-- Glongnom POS — Migration 012: BOM seed — common base ingredients
-- Targets: all active menus in categories 'Matcha' and 'Drinks'
--          (12 Matcha + 7 Drinks = 19 menus)
-- Safe to re-run: Step 1 skips existing names, Step 2 uses
--                 ON CONFLICT DO NOTHING on (menu_id, ingredient_id).
-- ============================================================

-- ── STEP 1: Insert ingredients that don't already exist ──────
INSERT INTO ingredients (name, unit, ingredient_type)
SELECT v.name, v.unit, v.ingredient_type
FROM (VALUES
  ('น้ำเชื่อมมิตรผล',                  'ml',  'ingredient'),
  ('น้ำแข็ง',                           'g',   'ingredient'),
  ('แก้ว PET 14oz + ฝายกดื่มปาก 98',   'pcs', 'packaging'),
  ('กระดาษปิดกันน้ำ',                   'pcs', 'packaging'),
  ('ถ้วยพลาสติก 3 oz',                  'pcs', 'packaging'),
  ('ถุงซิปน้ำแข็ง 12*17',              'pcs', 'packaging'),
  ('ถุงหิ้วเดี่ยวไฮโซ',                'pcs', 'packaging'),
  ('หลอดไม่งอ 6 มิล',                  'pcs', 'packaging')
) AS v(name, unit, ingredient_type)
WHERE NOT EXISTS (
  SELECT 1 FROM ingredients WHERE name = v.name AND is_active = true
);

-- ── STEP 2: Add BOM entries for every Matcha & Drinks menu ───
INSERT INTO recipe_bom (menu_id, ingredient_id, quantity_used)
SELECT
  m.id  AS menu_id,
  i.id  AS ingredient_id,
  v.qty AS quantity_used
FROM menus m
JOIN categories c ON c.id = m.category_id
CROSS JOIN (VALUES
  ('น้ำเชื่อมมิตรผล',                  24::numeric),
  ('น้ำแข็ง',                           150::numeric),
  ('แก้ว PET 14oz + ฝายกดื่มปาก 98',   1::numeric),
  ('กระดาษปิดกันน้ำ',                   1::numeric),
  ('ถ้วยพลาสติก 3 oz',                  1::numeric),
  ('ถุงซิปน้ำแข็ง 12*17',              1::numeric),
  ('ถุงหิ้วเดี่ยวไฮโซ',                1::numeric),
  ('หลอดไม่งอ 6 มิล',                  1::numeric)
) AS v(ing_name, qty)
JOIN ingredients i ON i.name = v.ing_name AND i.is_active = true
WHERE c.name IN ('Matcha', 'Drinks')
  AND m.is_active = true
ON CONFLICT (menu_id, ingredient_id) DO NOTHING;

-- ── VERIFY: count BOM entries per menu after insert ──────────
SELECT
  c.name          AS category,
  m.name          AS menu_item,
  count(rb.id)    AS bom_entries
FROM menus m
JOIN categories c   ON c.id = m.category_id
LEFT JOIN recipe_bom rb ON rb.menu_id = m.id
WHERE c.name IN ('Matcha', 'Drinks')
  AND m.is_active = true
GROUP BY c.name, m.name
ORDER BY c.name, m.name;
-- Expected: each row shows 8 (or more if prior BOM entries already existed)
