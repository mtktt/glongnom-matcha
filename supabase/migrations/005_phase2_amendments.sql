-- ============================================================
-- Migration 005 — Phase 2 Amendments
-- Run in Supabase SQL Editor after migration 004 is already live.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1a. Expand purchase_orders.status to include 'partial'
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.purchase_orders
  DROP CONSTRAINT IF EXISTS purchase_orders_status_check;

ALTER TABLE public.purchase_orders
  ADD CONSTRAINT purchase_orders_status_check
  CHECK (status IN ('draft', 'submitted', 'partial', 'received', 'cancelled'));


-- ─────────────────────────────────────────────────────────────
-- 1b. receive_po_items — atomic goods-receipt function
--
-- Accepts a PO id and a JSONB array of receipts:
--   [{ item_id: uuid, qty_received: numeric, unit_cost: numeric }]
--
-- For each receipt row it will:
--   • Guard against over-receipt (received > ordered)
--   • Update purchase_order_items (cumulative qty + actual unit cost)
--   • Update ingredients (stock increment + weighted-average cost)
--   • Insert one inventory_adjustments row for the audit trail
--
-- After processing all rows it transitions the PO status:
--   → 'received'  if every line item is fully received
--   → 'partial'   if at least one line item is still outstanding
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.receive_po_items(
  p_po_id    uuid,
  p_receipts jsonb  -- array of {item_id: uuid, qty_received: numeric, unit_cost: numeric}
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_receipt        record;
  v_item           record;
  v_new_cost       numeric(10,2);
  v_all_received   boolean;
  v_supplier_name  text;
BEGIN
  -- Resolve supplier name once for the audit log reason string
  SELECT s.name INTO v_supplier_name
  FROM purchase_orders po
  LEFT JOIN suppliers s ON s.id = po.supplier_id
  WHERE po.id = p_po_id;

  FOR v_receipt IN
    SELECT * FROM jsonb_to_recordset(p_receipts)
      AS x(item_id uuid, qty_received numeric, unit_cost numeric)
  LOOP
    -- Skip rows where nothing is being received
    CONTINUE WHEN v_receipt.qty_received IS NULL OR v_receipt.qty_received <= 0;

    -- Fetch PO line item joined with current ingredient stock / cost
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

    -- Guard: cumulative received cannot exceed ordered quantity
    IF v_item.already_received + v_receipt.qty_received > v_item.quantity_ordered THEN
      RAISE EXCEPTION 'Receipt quantity exceeds ordered quantity for item %', v_receipt.item_id;
    END IF;

    -- Weighted average cost: blend existing stock cost with incoming batch cost
    IF v_item.current_stock + v_receipt.qty_received > 0 THEN
      v_new_cost := ROUND(
        (  (v_item.current_stock  * v_item.cost_per_unit)
         + (v_receipt.qty_received * v_receipt.unit_cost) )
        / (v_item.current_stock + v_receipt.qty_received),
        2
      );
    ELSE
      -- Edge case: stock was at zero before receipt
      v_new_cost := v_receipt.unit_cost;
    END IF;

    -- Update PO line item: add to cumulative received qty, record actual unit cost
    UPDATE purchase_order_items
    SET quantity_received = quantity_received + v_receipt.qty_received,
        unit_cost         = v_receipt.unit_cost
    WHERE id = v_receipt.item_id;

    -- Update ingredient: increment stock, apply rolling average cost
    UPDATE ingredients
    SET current_stock = current_stock + v_receipt.qty_received,
        cost_per_unit = v_new_cost,
        updated_at    = now()
    WHERE id = v_item.ingredient_id;

    -- Audit log: one row per ingredient received in this session
    INSERT INTO inventory_adjustments
      (ingredient_id, delta, adjustment_type, reason, adjusted_by)
    VALUES
      ( v_item.ingredient_id,
        v_receipt.qty_received,
        'purchase',
        'PO #' || LEFT(p_po_id::text, 8) || ' — ' || COALESCE(v_supplier_name, 'supplier'),
        auth.uid() );
  END LOOP;

  -- Determine whether every line item in this PO is now fully received
  SELECT NOT EXISTS (
    SELECT 1 FROM purchase_order_items
    WHERE purchase_order_id = p_po_id
      AND quantity_received < quantity_ordered
  ) INTO v_all_received;

  -- Transition PO status; only stamp received_at when fully done
  UPDATE purchase_orders
  SET status      = CASE WHEN v_all_received THEN 'received' ELSE 'partial' END,
      received_at = CASE WHEN v_all_received THEN now() ELSE received_at END
  WHERE id = p_po_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.receive_po_items TO authenticated;
