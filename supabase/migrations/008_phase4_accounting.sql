-- ============================================================
-- Migration 008: Phase 4 — Accounting & Finance
-- Creates accounting_entries, fixed_costs, and auto-record
-- stored functions. Idempotent (IF NOT EXISTS throughout).
-- ============================================================

-- ── Table: accounting_entries ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.accounting_entries (
  id             uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_date     date          NOT NULL DEFAULT CURRENT_DATE,
  description    text          NOT NULL,
  amount         numeric(12,2) NOT NULL,  -- always positive
  entry_type     text          NOT NULL CHECK (entry_type IN ('income','expense')),
  category       text          NOT NULL DEFAULT 'other'
                 CHECK (category IN ('sales','purchase','labor','rent','utilities','other')),
  reference_type text          CHECK (reference_type IN ('order','purchase_order','manual')),
  reference_id   uuid,         -- order.id or purchase_order.id
  is_auto        boolean       NOT NULL DEFAULT false,  -- true = system-generated, cannot delete
  created_by     uuid          REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at     timestamptz   DEFAULT now(),
  updated_at     timestamptz   DEFAULT now()
);

ALTER TABLE public.accounting_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "accounting_read"  ON public.accounting_entries;
DROP POLICY IF EXISTS "accounting_write" ON public.accounting_entries;

CREATE POLICY "accounting_read" ON public.accounting_entries
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "accounting_write" ON public.accounting_entries
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role IN ('admin','manager')
    )
  );


-- ── Table: fixed_costs ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fixed_costs (
  id             uuid          DEFAULT gen_random_uuid() PRIMARY KEY,
  name           text          NOT NULL,
  amount         numeric(12,2) NOT NULL CHECK (amount >= 0),
  period_type    text          NOT NULL DEFAULT 'monthly'
                 CHECK (period_type IN ('monthly','weekly','yearly')),
  effective_from date          NOT NULL DEFAULT CURRENT_DATE,
  effective_to   date,         -- NULL = ongoing
  is_active      boolean       NOT NULL DEFAULT true,
  created_by     uuid          REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  created_at     timestamptz   DEFAULT now()
);

ALTER TABLE public.fixed_costs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fixed_costs_read"  ON public.fixed_costs;
DROP POLICY IF EXISTS "fixed_costs_write" ON public.fixed_costs;

CREATE POLICY "fixed_costs_read" ON public.fixed_costs
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "fixed_costs_write" ON public.fixed_costs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND role IN ('admin','manager')
    )
  );


-- ── Function: record_order_income ──────────────────────────
-- Called after an order is marked paid.
-- Idempotent: skips if an auto-entry already exists for this order.
CREATE OR REPLACE FUNCTION record_order_income(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total    numeric;
  v_order_no text;
BEGIN
  -- Idempotency: skip if already recorded
  IF EXISTS (
    SELECT 1 FROM accounting_entries
    WHERE reference_id = p_order_id
      AND reference_type = 'order'
      AND is_auto = true
  ) THEN
    RETURN;
  END IF;

  SELECT total_price, order_no
    INTO v_total, v_order_no
    FROM orders
   WHERE id = p_order_id;

  IF v_total IS NULL OR v_total <= 0 THEN RETURN; END IF;

  INSERT INTO accounting_entries
    (entry_date, description, amount, entry_type, category, reference_type, reference_id, is_auto)
  VALUES
    (CURRENT_DATE,
     'Sales — Order #' || v_order_no,
     v_total,
     'income',
     'sales',
     'order',
     p_order_id,
     true);
END;
$$;


-- ── Function: record_purchase_expense ──────────────────────
-- Called after a purchase order is fully received.
-- Idempotent: skips if an auto-entry already exists for this PO.
CREATE OR REPLACE FUNCTION record_purchase_expense(p_po_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_total numeric;
BEGIN
  -- Idempotency: skip if already recorded
  IF EXISTS (
    SELECT 1 FROM accounting_entries
    WHERE reference_id = p_po_id
      AND reference_type = 'purchase_order'
      AND is_auto = true
  ) THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(poi.quantity_ordered * poi.unit_cost), 0)
    INTO v_total
    FROM purchase_order_items poi
   WHERE poi.purchase_order_id = p_po_id;

  IF v_total <= 0 THEN RETURN; END IF;

  INSERT INTO accounting_entries
    (entry_date, description, amount, entry_type, category, reference_type, reference_id, is_auto)
  VALUES
    (CURRENT_DATE,
     'Purchase — PO #' || p_po_id::text,
     v_total,
     'expense',
     'purchase',
     'purchase_order',
     p_po_id,
     true);
END;
$$;
