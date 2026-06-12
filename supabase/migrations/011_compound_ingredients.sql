-- ============================================================
-- Glongnom POS — Migration 011: Compound Ingredients
-- ============================================================
-- 1. Fix cost_per_unit column — original numeric(10,2) truncated
--    values like 0.0045 → 0.00, causing the "0.0000 THB/ml" bug.
-- 2. Add is_compound + batch_yield to ingredients.
-- 3. New compound_ingredient_parts table.
-- 4. Replace deduct_bom_for_order with chain-deduction version.
-- ============================================================

-- ── 1. Fix cost_per_unit precision ───────────────────────────
ALTER TABLE ingredients ALTER COLUMN cost_per_unit TYPE numeric;

-- ── 2. Compound columns ───────────────────────────────────────
ALTER TABLE ingredients
  ADD COLUMN IF NOT EXISTS is_compound boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS batch_yield numeric DEFAULT 1; -- in small units

-- ── 3. Compound ingredient parts ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.compound_ingredient_parts (
  id                     uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  compound_ingredient_id uuid          NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  part_ingredient_id     uuid          NOT NULL REFERENCES ingredients(id),
  quantity_per_batch     numeric       NOT NULL CHECK (quantity_per_batch > 0),
  UNIQUE (compound_ingredient_id, part_ingredient_id)
);

ALTER TABLE public.compound_ingredient_parts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cip_select" ON public.compound_ingredient_parts FOR SELECT
  TO authenticated USING (auth.uid() IS NOT NULL);

CREATE POLICY "cip_insert" ON public.compound_ingredient_parts FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "cip_update" ON public.compound_ingredient_parts FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "cip_delete" ON public.compound_ingredient_parts FOR DELETE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE INDEX IF NOT EXISTS cip_compound_idx ON public.compound_ingredient_parts(compound_ingredient_id);

-- ── 4. Replace deduct_bom_for_order ──────────────────────────
-- Changes vs original:
--   • Compound ingredients chain-deduct to their raw parts.
--   • ON CONFLICT DO UPDATE aggregates quantities so the same raw
--     ingredient can be reached via multiple compound BOM entries.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.deduct_bom_for_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item    RECORD;
  v_bom     RECORD;
  v_part    RECORD;
  v_total   numeric;
  v_batches numeric;
BEGIN
  -- Idempotency: if ANY deduction exists for this order, skip entirely.
  IF EXISTS (SELECT 1 FROM inventory_deductions WHERE order_id = p_order_id LIMIT 1) THEN
    RETURN;
  END IF;

  FOR v_item IN
    SELECT oi.menu_id, oi.qty
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    FOR v_bom IN
      SELECT rb.ingredient_id, rb.quantity_used, i.is_compound, i.batch_yield
      FROM recipe_bom rb
      JOIN ingredients i ON i.id = rb.ingredient_id
      WHERE rb.menu_id = v_item.menu_id AND i.is_active = true
    LOOP
      v_total := v_bom.quantity_used * v_item.qty;

      IF v_bom.is_compound AND v_bom.batch_yield > 0 THEN
        -- ── Chain deduction: resolve compound → raw parts ──
        v_batches := v_total / v_bom.batch_yield;

        FOR v_part IN
          SELECT part_ingredient_id, quantity_per_batch
          FROM compound_ingredient_parts
          WHERE compound_ingredient_id = v_bom.ingredient_id
        LOOP
          UPDATE ingredients
          SET current_stock = GREATEST(0, current_stock - (v_part.quantity_per_batch * v_batches)),
              updated_at    = now()
          WHERE id = v_part.part_ingredient_id;

          -- Aggregate if same raw ingredient deducted more than once
          INSERT INTO inventory_deductions (order_id, ingredient_id, quantity_deducted)
          VALUES (p_order_id, v_part.part_ingredient_id, v_part.quantity_per_batch * v_batches)
          ON CONFLICT (order_id, ingredient_id) DO UPDATE
            SET quantity_deducted =
              inventory_deductions.quantity_deducted + EXCLUDED.quantity_deducted;
        END LOOP;

      ELSE
        -- ── Normal deduction ──
        UPDATE ingredients
        SET current_stock = GREATEST(0, current_stock - v_total),
            updated_at    = now()
        WHERE id = v_bom.ingredient_id;

        INSERT INTO inventory_deductions (order_id, ingredient_id, quantity_deducted)
        VALUES (p_order_id, v_bom.ingredient_id, v_total)
        ON CONFLICT (order_id, ingredient_id) DO UPDATE
          SET quantity_deducted =
            inventory_deductions.quantity_deducted + EXCLUDED.quantity_deducted;
      END IF;

    END LOOP;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deduct_bom_for_order TO authenticated;
