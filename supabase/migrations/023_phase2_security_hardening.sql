-- ============================================================
-- Glongnom POS — Migration 023: Phase 2 security hardening
-- ============================================================
-- Two fixes from the 2026-06 code review:
--
-- A5 — `customers_update` was created in migration 009 as
--      USING (true) WITH CHECK (true), so ANYONE with the anon key
--      can UPDATE any customer row (name/address/phone/notes) via a
--      direct REST call. Migration 022 closed the INSERT hole but
--      left this UPDATE hole open. The customer app no longer writes
--      customers directly (create_order() does it as SECURITY DEFINER,
--      bypassing RLS), so we can safely restrict this to staff.
--
-- D2 — receive_po_items() and record_purchase_expense() are
--      SECURITY DEFINER and GRANTed to `authenticated` with no
--      internal role check, so any logged-in user (cashier, kitchen,
--      staff) could call them from the console. They are only ever
--      invoked from the admin/manager-gated Purchase Orders page, so
--      we add an explicit role guard. receive_po_items is the most
--      important — it moves stock and rewrites weighted-average cost.
--
--      NOTE: record_order_income() is intentionally NOT guarded. It is
--      called by markPaid() on the orders page, which is open to ALL
--      staff roles (admin/manager/cashier/kitchen/staff). Guarding it
--      would break kitchen/staff marking an order paid. Its blast
--      radius is minimal: it is idempotent and only records the order's
--      own server-authoritative total_price (locked down in 021).
--
-- Run in: Supabase Dashboard → SQL Editor → New Query.
-- ============================================================

-- ── A5: customers UPDATE → staff only ───────────────────────
DROP POLICY IF EXISTS "customers_update" ON public.customers;

CREATE POLICY "customers_staff_update" ON public.customers
  FOR UPDATE
  USING      (current_user_role() IN ('admin','manager','cashier'))
  WITH CHECK (current_user_role() IN ('admin','manager','cashier'));

-- ── D2: role-guard the PO financial functions ───────────────
-- receive_po_items — body reproduced verbatim from migration 013,
-- with a role guard added at the top.
CREATE OR REPLACE FUNCTION public.receive_po_items(
  p_po_id    uuid,
  p_receipts jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_receipt        record;
  v_item           record;
  v_new_cost       numeric;
  v_all_received   boolean;
  v_supplier_name  text;
BEGIN
  -- D2 guard: goods receipt is an admin/manager operation only.
  IF current_user_role() NOT IN ('admin','manager') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: receive_po_items requires admin or manager';
  END IF;

  SELECT s.name INTO v_supplier_name
  FROM purchase_orders po
  LEFT JOIN suppliers s ON s.id = po.supplier_id
  WHERE po.id = p_po_id;

  FOR v_receipt IN
    SELECT * FROM jsonb_to_recordset(p_receipts)
      AS x(item_id uuid, qty_received numeric, unit_cost numeric)
  LOOP
    CONTINUE WHEN v_receipt.qty_received IS NULL OR v_receipt.qty_received <= 0;

    SELECT poi.ingredient_id,
           poi.quantity_ordered,
           poi.quantity_received AS already_received,
           i.current_stock,
           i.cost_per_unit
    INTO v_item
    FROM purchase_order_items poi
    JOIN ingredients i ON i.id = poi.ingredient_id
    WHERE poi.id = v_receipt.item_id
      AND poi.purchase_order_id = p_po_id;

    IF NOT FOUND THEN CONTINUE; END IF;

    IF v_item.already_received + v_receipt.qty_received > v_item.quantity_ordered THEN
      RAISE EXCEPTION 'Receipt quantity exceeds ordered quantity for item %', v_receipt.item_id;
    END IF;

    -- Weighted average cost — 6dp to preserve small per-unit values
    IF v_item.current_stock + v_receipt.qty_received > 0 THEN
      v_new_cost := ROUND(
        (  (v_item.current_stock   * v_item.cost_per_unit)
         + (v_receipt.qty_received * v_receipt.unit_cost ) )
        / (v_item.current_stock + v_receipt.qty_received),
        6
      );
    ELSE
      v_new_cost := v_receipt.unit_cost;
    END IF;

    UPDATE purchase_order_items
    SET quantity_received = quantity_received + v_receipt.qty_received,
        unit_cost         = v_receipt.unit_cost
    WHERE id = v_receipt.item_id;

    UPDATE ingredients
    SET current_stock = current_stock + v_receipt.qty_received,
        cost_per_unit = v_new_cost,
        updated_at    = now()
    WHERE id = v_item.ingredient_id;

    INSERT INTO inventory_adjustments
      (ingredient_id, delta, adjustment_type, reason, adjusted_by)
    VALUES
      ( v_item.ingredient_id,
        v_receipt.qty_received,
        'purchase',
        'PO #' || LEFT(p_po_id::text, 8) || ' — ' || COALESCE(v_supplier_name, 'supplier'),
        auth.uid() );
  END LOOP;

  SELECT NOT EXISTS (
    SELECT 1 FROM purchase_order_items
    WHERE purchase_order_id = p_po_id
      AND quantity_received < quantity_ordered
  ) INTO v_all_received;

  UPDATE purchase_orders
  SET status      = CASE WHEN v_all_received THEN 'received' ELSE 'partial' END,
      received_at = CASE WHEN v_all_received THEN now() ELSE received_at END
  WHERE id = p_po_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.receive_po_items TO authenticated;

-- record_purchase_expense — body reproduced verbatim from migration 016,
-- with a role guard added at the top.
CREATE OR REPLACE FUNCTION public.record_purchase_expense(p_po_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_total numeric;
BEGIN
  -- D2 guard: expense recording follows goods receipt — admin/manager only.
  IF current_user_role() NOT IN ('admin','manager') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: record_purchase_expense requires admin or manager';
  END IF;

  IF EXISTS (
    SELECT 1 FROM accounting_entries
    WHERE reference_id = p_po_id AND reference_type = 'purchase_order' AND is_auto = true
  ) THEN RETURN; END IF;

  SELECT COALESCE(SUM(poi.quantity_received * poi.unit_cost), 0)
  INTO v_total
  FROM purchase_order_items poi
  WHERE poi.purchase_order_id = p_po_id AND poi.quantity_received > 0;

  IF v_total <= 0 THEN RETURN; END IF;

  INSERT INTO accounting_entries
    (entry_date, description, amount, entry_type, category, reference_type, reference_id, is_auto)
  VALUES (
    (NOW() AT TIME ZONE 'Asia/Bangkok')::date,
    'Purchase — PO #' || UPPER(LEFT(p_po_id::text, 8)),
    v_total, 'expense', 'purchase', 'purchase_order', p_po_id, true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_purchase_expense TO authenticated;

-- ------------------------------------------------------------
-- ROLLBACK (uncomment to restore previous behavior):
--   DROP POLICY IF EXISTS "customers_staff_update" ON public.customers;
--   CREATE POLICY "customers_update" ON public.customers
--     FOR UPDATE USING (true) WITH CHECK (true);
--   -- and re-run migrations 013 + 016 to drop the function role guards.
-- ------------------------------------------------------------
