-- ============================================================
-- Glongnom POS — Migration 017: BOM Option Overrides
-- Lets option choices modify ingredient deduction rules.
--
-- 3 action types per choice:
--   replace — swap a default BOM ingredient with another
--   add     — inject extra ingredients not in base BOM
--   remove  — skip a default BOM ingredient entirely
-- ============================================================

-- ── 1. Table ─────────────────────────────────────────────────
CREATE TABLE public.bom_option_overrides (
  id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  choice_id            uuid NOT NULL REFERENCES option_template_choices(id) ON DELETE CASCADE,
  action               text NOT NULL CHECK (action IN ('replace', 'add', 'remove')),
  -- ingredient being replaced or removed (required for 'replace' and 'remove')
  target_ingredient_id uuid REFERENCES ingredients(id) ON DELETE CASCADE,
  -- ingredient to use instead or to add (required for 'replace' and 'add')
  ingredient_id        uuid REFERENCES ingredients(id) ON DELETE CASCADE,
  -- quantity to use; null on 'replace' means "same qty as the original BOM entry"
  quantity_used        numeric CHECK (quantity_used IS NULL OR quantity_used > 0),
  created_at           timestamptz DEFAULT now(),

  CONSTRAINT bom_override_replace_fields CHECK (
    action <> 'replace' OR (target_ingredient_id IS NOT NULL AND ingredient_id IS NOT NULL)
  ),
  CONSTRAINT bom_override_add_fields CHECK (
    action <> 'add' OR (ingredient_id IS NOT NULL AND quantity_used IS NOT NULL)
  ),
  CONSTRAINT bom_override_remove_fields CHECK (
    action <> 'remove' OR target_ingredient_id IS NOT NULL
  )
);

CREATE INDEX ON public.bom_option_overrides (choice_id);
CREATE INDEX ON public.bom_option_overrides (ingredient_id);
CREATE INDEX ON public.bom_option_overrides (target_ingredient_id);

-- ── 2. RLS ───────────────────────────────────────────────────
ALTER TABLE public.bom_option_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bom_overrides_select" ON public.bom_option_overrides
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

CREATE POLICY "bom_overrides_insert" ON public.bom_option_overrides
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "bom_overrides_update" ON public.bom_option_overrides
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "bom_overrides_delete" ON public.bom_option_overrides
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );


-- ── 3. Helper: deduct one ingredient (normal or compound) ────
-- Extracted from deduct_bom_for_order to avoid repeating chain-deduction logic.
CREATE OR REPLACE FUNCTION public._do_ingredient_deduction(
  p_order_id      uuid,
  p_ingredient_id uuid,
  p_total         numeric,
  p_is_compound   boolean,
  p_batch_yield   numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batches numeric;
  v_part    RECORD;
BEGIN
  IF p_is_compound AND p_batch_yield > 0 THEN
    v_batches := p_total / p_batch_yield;

    FOR v_part IN
      SELECT part_ingredient_id, quantity_per_batch
      FROM compound_ingredient_parts
      WHERE compound_ingredient_id = p_ingredient_id
    LOOP
      UPDATE ingredients
      SET current_stock = GREATEST(0, current_stock - (v_part.quantity_per_batch * v_batches)),
          updated_at    = now()
      WHERE id = v_part.part_ingredient_id;

      INSERT INTO inventory_deductions (order_id, ingredient_id, quantity_deducted)
      VALUES (p_order_id, v_part.part_ingredient_id, v_part.quantity_per_batch * v_batches)
      ON CONFLICT (order_id, ingredient_id) DO UPDATE
        SET quantity_deducted = inventory_deductions.quantity_deducted + EXCLUDED.quantity_deducted;
    END LOOP;

  ELSE
    UPDATE ingredients
    SET current_stock = GREATEST(0, current_stock - p_total),
        updated_at    = now()
    WHERE id = p_ingredient_id;

    INSERT INTO inventory_deductions (order_id, ingredient_id, quantity_deducted)
    VALUES (p_order_id, p_ingredient_id, p_total)
    ON CONFLICT (order_id, ingredient_id) DO UPDATE
      SET quantity_deducted = inventory_deductions.quantity_deducted + EXCLUDED.quantity_deducted;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public._do_ingredient_deduction TO authenticated;


-- ── 4. Updated deduct_bom_for_order with option overrides ────
-- Per order_item:
--   Phase 1 — base BOM, skipping ingredients overridden by chosen options
--   Phase 2 — replace overrides: deduct the replacement ingredient
--   Phase 3 — add overrides: inject extra ingredients
CREATE OR REPLACE FUNCTION public.deduct_bom_for_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item     RECORD;
  v_bom      RECORD;
  v_override RECORD;
  v_ing      RECORD;
  v_total    numeric;
  v_choices  uuid[];
  v_skip_ids uuid[];
BEGIN
  -- Idempotency guard: any existing deduction row means this order was already processed
  IF EXISTS (SELECT 1 FROM inventory_deductions WHERE order_id = p_order_id LIMIT 1) THEN
    RETURN;
  END IF;

  FOR v_item IN
    SELECT oi.id AS order_item_id, oi.menu_id, oi.qty
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    -- Collect the choice IDs selected for this order item
    SELECT COALESCE(array_agg(oio.choice_id), '{}') INTO v_choices
    FROM order_item_options oio
    WHERE oio.order_item_id = v_item.order_item_id;

    -- Build skip list: default ingredients being replaced or removed by chosen options
    SELECT COALESCE(array_agg(DISTINCT boo.target_ingredient_id), '{}') INTO v_skip_ids
    FROM bom_option_overrides boo
    WHERE boo.choice_id = ANY(v_choices)
      AND boo.action IN ('remove', 'replace')
      AND boo.target_ingredient_id IS NOT NULL;

    -- Phase 1: Base BOM, excluding overridden ingredients
    FOR v_bom IN
      SELECT rb.ingredient_id, rb.quantity_used, i.is_compound, i.batch_yield
      FROM recipe_bom rb
      JOIN ingredients i ON i.id = rb.ingredient_id
      WHERE rb.menu_id = v_item.menu_id
        AND i.is_active = true
        AND NOT (rb.ingredient_id = ANY(v_skip_ids))
    LOOP
      PERFORM _do_ingredient_deduction(
        p_order_id, v_bom.ingredient_id,
        v_bom.quantity_used * v_item.qty,
        v_bom.is_compound, v_bom.batch_yield
      );
    END LOOP;

    -- Phase 2: Replace overrides — deduct the substitute ingredient
    FOR v_override IN
      SELECT DISTINCT ON (boo.target_ingredient_id)
        boo.ingredient_id,
        boo.target_ingredient_id,
        boo.quantity_used AS override_qty
      FROM bom_option_overrides boo
      WHERE boo.choice_id = ANY(v_choices)
        AND boo.action = 'replace'
        AND boo.ingredient_id IS NOT NULL
      ORDER BY boo.target_ingredient_id, boo.created_at DESC
    LOOP
      -- null override_qty → inherit quantity from the original BOM entry
      IF v_override.override_qty IS NOT NULL THEN
        v_total := v_override.override_qty * v_item.qty;
      ELSE
        SELECT rb.quantity_used * v_item.qty INTO v_total
        FROM recipe_bom rb
        WHERE rb.menu_id = v_item.menu_id
          AND rb.ingredient_id = v_override.target_ingredient_id;
        IF NOT FOUND THEN CONTINUE; END IF;
      END IF;

      SELECT is_compound, batch_yield INTO v_ing
      FROM ingredients
      WHERE id = v_override.ingredient_id AND is_active = true;

      IF FOUND THEN
        PERFORM _do_ingredient_deduction(
          p_order_id, v_override.ingredient_id, v_total,
          v_ing.is_compound, v_ing.batch_yield
        );
      END IF;
    END LOOP;

    -- Phase 3: Add overrides — inject extra ingredients not in base BOM
    FOR v_override IN
      SELECT boo.ingredient_id, boo.quantity_used
      FROM bom_option_overrides boo
      WHERE boo.choice_id = ANY(v_choices)
        AND boo.action = 'add'
        AND boo.ingredient_id IS NOT NULL
        AND boo.quantity_used IS NOT NULL
    LOOP
      SELECT is_compound, batch_yield INTO v_ing
      FROM ingredients
      WHERE id = v_override.ingredient_id AND is_active = true;

      IF FOUND THEN
        PERFORM _do_ingredient_deduction(
          p_order_id, v_override.ingredient_id,
          v_override.quantity_used * v_item.qty,
          v_ing.is_compound, v_ing.batch_yield
        );
      END IF;
    END LOOP;

  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deduct_bom_for_order TO authenticated;
