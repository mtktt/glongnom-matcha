-- ============================================================
-- Glongnom POS — Migration 015: Backfill accounting entries
-- ============================================================
-- Migration 014 fixed the GRANT so new transactions now record.
-- This migration backfills ALL historical paid orders and
-- received POs that never got an accounting entry.
--
-- entry_date uses Bangkok timezone (UTC+7) so dates appear
-- correctly in the accounting page's period filters.
-- Safe to re-run: the WHERE NOT EXISTS guard prevents duplicates.
-- ============================================================

-- ── 1. Backfill income for all paid orders ────────────────────
INSERT INTO accounting_entries
  (entry_date, description, amount, entry_type, category,
   reference_type, reference_id, is_auto)
SELECT
  DATE(o.created_at AT TIME ZONE 'Asia/Bangkok')                   AS entry_date,
  'Sales — Order #' || COALESCE(o.order_no, LEFT(o.id::text, 8))   AS description,
  o.total_price                                                      AS amount,
  'income',
  'sales',
  'order',
  o.id,
  true
FROM orders o
WHERE o.payment_status = 'paid'
  AND o.total_price > 0
  AND o.status != 'cancelled'
  AND NOT EXISTS (
    SELECT 1 FROM accounting_entries ae
    WHERE ae.reference_id    = o.id
      AND ae.reference_type  = 'order'
      AND ae.is_auto         = true
  );

-- ── 2. Backfill expense for all received / partial POs ────────
INSERT INTO accounting_entries
  (entry_date, description, amount, entry_type, category,
   reference_type, reference_id, is_auto)
SELECT
  COALESCE(
    DATE(po.received_at AT TIME ZONE 'Asia/Bangkok'),
    CURRENT_DATE
  )                                                                  AS entry_date,
  'Purchase — PO #' || LEFT(po.id::text, 8)                         AS description,
  COALESCE(SUM(poi.quantity_received * poi.unit_cost), 0)            AS amount,
  'expense',
  'purchase',
  'purchase_order',
  po.id,
  true
FROM purchase_orders po
JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
WHERE po.status IN ('received', 'partial')
  AND NOT EXISTS (
    SELECT 1 FROM accounting_entries ae
    WHERE ae.reference_id   = po.id
      AND ae.reference_type = 'purchase_order'
      AND ae.is_auto        = true
  )
GROUP BY po.id, po.received_at
HAVING COALESCE(SUM(poi.quantity_received * poi.unit_cost), 0) > 0;

-- ── Verify: count entries created ────────────────────────────
SELECT
  entry_type,
  category,
  COUNT(*)        AS entries,
  SUM(amount)     AS total_amount,
  MIN(entry_date) AS earliest,
  MAX(entry_date) AS latest
FROM accounting_entries
WHERE is_auto = true
GROUP BY entry_type, category
ORDER BY entry_type, category;
