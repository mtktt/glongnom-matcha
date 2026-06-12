-- ============================================================
-- Migration 004 — Phase 2: Inventory, BOM, Suppliers & Purchase Orders
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================


-- ──────────────────────────────────────────────────────────────
-- 1. INGREDIENTS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.ingredients (
  id             uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  shop_id        uuid         REFERENCES public.shops(id) ON DELETE CASCADE,
  name           text         NOT NULL,
  unit           text         NOT NULL CHECK (unit IN ('g','ml','pcs','kg','L','tbsp','tsp','sheet')),
  current_stock  numeric(10,3) NOT NULL DEFAULT 0,
  reorder_level  numeric(10,3) NOT NULL DEFAULT 0,
  cost_per_unit  numeric(10,2) NOT NULL DEFAULT 0,
  is_active      boolean      NOT NULL DEFAULT true,
  created_at     timestamptz  DEFAULT now(),
  updated_at     timestamptz  DEFAULT now()
);

-- ──────────────────────────────────────────────────────────────
-- 2. RECIPE BOM  (Bill of Materials per menu item)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.recipe_bom (
  id              uuid         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  menu_id         uuid         NOT NULL REFERENCES public.menus(id) ON DELETE CASCADE,
  ingredient_id   uuid         NOT NULL REFERENCES public.ingredients(id) ON DELETE RESTRICT,
  quantity_used   numeric(10,3) NOT NULL CHECK (quantity_used > 0),
  created_at      timestamptz  DEFAULT now(),
  UNIQUE (menu_id, ingredient_id)
);

-- ──────────────────────────────────────────────────────────────
-- 3. INVENTORY ADJUSTMENTS  (manual stock changes & receipts)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.inventory_adjustments (
  id               uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  ingredient_id    uuid          NOT NULL REFERENCES public.ingredients(id) ON DELETE RESTRICT,
  delta            numeric(10,3) NOT NULL,  -- positive = add, negative = reduce
  adjustment_type  text          NOT NULL CHECK (adjustment_type IN ('purchase','manual','wastage','count','other')),
  reason           text,
  adjusted_by      uuid          REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at       timestamptz   DEFAULT now()
);

-- ──────────────────────────────────────────────────────────────
-- 4. INVENTORY DEDUCTIONS  (idempotency log for the BOM engine)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.inventory_deductions (
  id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id           uuid          NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  ingredient_id      uuid          NOT NULL REFERENCES public.ingredients(id) ON DELETE RESTRICT,
  quantity_deducted  numeric(10,3) NOT NULL,
  deducted_at        timestamptz   DEFAULT now(),
  UNIQUE (order_id, ingredient_id)
);

-- ──────────────────────────────────────────────────────────────
-- 5. SUPPLIERS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.suppliers (
  id            uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name          text        NOT NULL,
  contact_name  text,
  phone         text,
  email         text,
  notes         text,
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz DEFAULT now()
);

-- ──────────────────────────────────────────────────────────────
-- 6. PURCHASE ORDERS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.purchase_orders (
  id           uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  supplier_id  uuid        REFERENCES public.suppliers(id) ON DELETE SET NULL,
  status       text        NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft','submitted','received','cancelled')),
  notes        text,
  created_by   uuid        REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at   timestamptz DEFAULT now(),
  received_at  timestamptz
);

-- ──────────────────────────────────────────────────────────────
-- 7. PURCHASE ORDER ITEMS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE public.purchase_order_items (
  id                 uuid          NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  purchase_order_id  uuid          NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  ingredient_id      uuid          NOT NULL REFERENCES public.ingredients(id) ON DELETE RESTRICT,
  quantity_ordered   numeric(10,3) NOT NULL CHECK (quantity_ordered > 0),
  quantity_received  numeric(10,3) DEFAULT 0,
  unit_cost          numeric(10,2) NOT NULL DEFAULT 0,
  notes              text
);


-- ──────────────────────────────────────────────────────────────
-- INDEXES
-- ──────────────────────────────────────────────────────────────
CREATE INDEX ON public.recipe_bom (menu_id);
CREATE INDEX ON public.recipe_bom (ingredient_id);
CREATE INDEX ON public.inventory_adjustments (ingredient_id);
CREATE INDEX ON public.inventory_adjustments (created_at DESC);
CREATE INDEX ON public.inventory_deductions (order_id);
CREATE INDEX ON public.ingredients (is_active, current_stock);
CREATE INDEX ON public.purchase_orders (status);
CREATE INDEX ON public.purchase_order_items (purchase_order_id);


-- ──────────────────────────────────────────────────────────────
-- updated_at AUTO-TRIGGER FOR ingredients
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ingredients_updated_at
BEFORE UPDATE ON public.ingredients
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ──────────────────────────────────────────────────────────────
-- STORED FUNCTION: deduct_bom_for_order
-- Called via supabase.rpc('deduct_bom_for_order', { p_order_id })
-- when an order transitions to status = 'served'.
-- Idempotent: safe to call multiple times for the same order.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.deduct_bom_for_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item  RECORD;
  v_bom   RECORD;
  v_total numeric;
BEGIN
  -- Loop over every line item in the order
  FOR v_item IN
    SELECT oi.menu_id, oi.qty
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    -- Loop over every BOM entry for this menu item
    FOR v_bom IN
      SELECT rb.ingredient_id, rb.quantity_used
      FROM recipe_bom rb
      WHERE rb.menu_id = v_item.menu_id
    LOOP
      v_total := v_bom.quantity_used * v_item.qty;

      -- Idempotency: skip if this (order, ingredient) pair was already deducted
      IF EXISTS (
        SELECT 1 FROM inventory_deductions
        WHERE order_id = p_order_id AND ingredient_id = v_bom.ingredient_id
      ) THEN
        CONTINUE;
      END IF;

      -- Deduct from stock; floor at 0 to prevent negative stock
      UPDATE ingredients
      SET current_stock = GREATEST(0, current_stock - v_total),
          updated_at    = now()
      WHERE id = v_bom.ingredient_id;

      -- Write idempotency log entry
      INSERT INTO inventory_deductions (order_id, ingredient_id, quantity_deducted)
      VALUES (p_order_id, v_bom.ingredient_id, v_total);

    END LOOP;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deduct_bom_for_order TO authenticated;


-- ──────────────────────────────────────────────────────────────
-- STORED FUNCTION: adjust_ingredient_stock
-- Called via supabase.rpc('adjust_ingredient_stock', { p_ingredient_id, p_delta })
-- for manual stock adjustments and wastage logging from the UI.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.adjust_ingredient_stock(
  p_ingredient_id uuid,
  p_delta         numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ingredients
  SET current_stock = GREATEST(0, current_stock + p_delta),
      updated_at    = now()
  WHERE id = p_ingredient_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.adjust_ingredient_stock TO authenticated;


-- ──────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ──────────────────────────────────────────────────────────────

-- Helper expression used in INSERT/UPDATE/DELETE policies:
-- "caller is an admin or manager"
-- EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))

-- ── ingredients ──────────────────────────────────────────────
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ingredients: authenticated can select"
  ON public.ingredients FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "ingredients: admin/manager can insert"
  ON public.ingredients FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "ingredients: admin/manager can update"
  ON public.ingredients FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "ingredients: admin/manager can delete"
  ON public.ingredients FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── recipe_bom ───────────────────────────────────────────────
ALTER TABLE public.recipe_bom ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipe_bom: authenticated can select"
  ON public.recipe_bom FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "recipe_bom: admin/manager can insert"
  ON public.recipe_bom FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "recipe_bom: admin/manager can update"
  ON public.recipe_bom FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "recipe_bom: admin/manager can delete"
  ON public.recipe_bom FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── inventory_adjustments ────────────────────────────────────
ALTER TABLE public.inventory_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_adjustments: authenticated can select"
  ON public.inventory_adjustments FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "inventory_adjustments: admin/manager can insert"
  ON public.inventory_adjustments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "inventory_adjustments: admin/manager can update"
  ON public.inventory_adjustments FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "inventory_adjustments: admin/manager can delete"
  ON public.inventory_adjustments FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── inventory_deductions ─────────────────────────────────────
ALTER TABLE public.inventory_deductions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_deductions: authenticated can select"
  ON public.inventory_deductions FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "inventory_deductions: admin/manager can insert"
  ON public.inventory_deductions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "inventory_deductions: admin/manager can update"
  ON public.inventory_deductions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "inventory_deductions: admin/manager can delete"
  ON public.inventory_deductions FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── suppliers ────────────────────────────────────────────────
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suppliers: authenticated can select"
  ON public.suppliers FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "suppliers: admin/manager can insert"
  ON public.suppliers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "suppliers: admin/manager can update"
  ON public.suppliers FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "suppliers: admin/manager can delete"
  ON public.suppliers FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── purchase_orders ──────────────────────────────────────────
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "purchase_orders: authenticated can select"
  ON public.purchase_orders FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "purchase_orders: admin/manager can insert"
  ON public.purchase_orders FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "purchase_orders: admin/manager can update"
  ON public.purchase_orders FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "purchase_orders: admin/manager can delete"
  ON public.purchase_orders FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

-- ── purchase_order_items ─────────────────────────────────────
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "purchase_order_items: authenticated can select"
  ON public.purchase_order_items FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "purchase_order_items: admin/manager can insert"
  ON public.purchase_order_items FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "purchase_order_items: admin/manager can update"
  ON public.purchase_order_items FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );

CREATE POLICY "purchase_order_items: admin/manager can delete"
  ON public.purchase_order_items FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
  );
