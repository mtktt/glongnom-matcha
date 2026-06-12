-- ============================================================
-- Glongnom POS — Migration 010: Ingredient Big/Small Unit System
-- ============================================================
-- Adds three columns to support the big-unit purchase / small-unit
-- usage paradigm (e.g. buy 1 kg, use in g; buy 1 bottle, use in ml).
-- All existing rows default gracefully (ingredient, NULL, 1).
-- ============================================================

ALTER TABLE ingredients
  ADD COLUMN IF NOT EXISTS ingredient_type text    DEFAULT 'ingredient'
    CHECK (ingredient_type IN ('ingredient','packaging')),
  ADD COLUMN IF NOT EXISTS big_unit        text,          -- purchase unit: kg / ขวด / กล่อง …
  ADD COLUMN IF NOT EXISTS units_per_big   numeric DEFAULT 1, -- small units per 1 big unit
  ADD COLUMN IF NOT EXISTS cost_per_big    numeric DEFAULT 0; -- purchase price per big unit (stored directly — no reverse-calc needed)
