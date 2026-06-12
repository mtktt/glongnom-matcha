-- ============================================================
-- Glongnom POS — Migration 014: Fix accounting function grants
-- ============================================================
-- Migration 008 created record_order_income and
-- record_purchase_expense but NEVER granted EXECUTE to the
-- authenticated role. Every call from the frontend was silently
-- rejected with "permission denied for function", and since both
-- callers used fire-and-forget .catch(), the error was swallowed
-- and no entries ever landed in accounting_entries.
-- ============================================================

-- Re-create both functions with SET search_path for safety, then grant.

CREATE OR REPLACE FUNCTION public.record_order_income(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_total    numeric;
  v_order_no text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM accounting_entries
    WHERE reference_id = p_order_id
      AND reference_type = 'order'
      AND is_auto = true
  ) THEN RETURN; END IF;

  SELECT total_price, order_no
    INTO v_total, v_order_no
    FROM orders WHERE id = p_order_id;

  IF v_total IS NULL OR v_total <= 0 THEN RETURN; END IF;

  INSERT INTO accounting_entries
    (entry_date, description, amount, entry_type, category, reference_type, reference_id, is_auto)
  VALUES
    (CURRENT_DATE,
     'Sales — Order #' || COALESCE(v_order_no, LEFT(p_order_id::text, 8)),
     v_total, 'income', 'sales', 'order', p_order_id, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_purchase_expense(p_po_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_total numeric;
BEGIN
  IF EXISTS (
    SELECT 1 FROM accounting_entries
    WHERE reference_id = p_po_id
      AND reference_type = 'purchase_order'
      AND is_auto = true
  ) THEN RETURN; END IF;

  -- Cost = quantity_received × unit_cost (small units already converted in receive flow)
  SELECT COALESCE(SUM(poi.quantity_received * poi.unit_cost), 0)
    INTO v_total
    FROM purchase_order_items poi
   WHERE poi.purchase_order_id = p_po_id
     AND poi.quantity_received > 0;

  IF v_total <= 0 THEN RETURN; END IF;

  INSERT INTO accounting_entries
    (entry_date, description, amount, entry_type, category, reference_type, reference_id, is_auto)
  VALUES
    (CURRENT_DATE,
     'Purchase — PO #' || LEFT(p_po_id::text, 8),
     v_total, 'expense', 'purchase', 'purchase_order', p_po_id, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_order_income     TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_purchase_expense TO authenticated;
