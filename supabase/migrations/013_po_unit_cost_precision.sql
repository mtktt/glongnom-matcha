-- ============================================================
-- Glongnom POS — Migration 013: Fix unit_cost precision
-- ============================================================
-- purchase_order_items.unit_cost was numeric(10,2) — storing
-- 0.075 (฿75/L ÷ 1000ml) rounded it to 0.08 → display back as
-- ฿80/L instead of ฿75/L.
-- Also update receive_po_items ROUND precision from 2 → 6 dp
-- so the weighted average cost stored in ingredients is accurate.
-- ============================================================

ALTER TABLE purchase_order_items
  ALTER COLUMN unit_cost TYPE numeric;

-- Re-create receive_po_items with 6dp precision on weighted average
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
        6   -- was 2; now matches the new cost_per_unit numeric precision
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
