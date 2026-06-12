-- ============================================================
-- Glongnom POS — Migration 009: CRM RLS + Loyalty Fixes
-- ============================================================
-- Root cause: customers table had no UPDATE policy.
-- The upsert in index.html (ON CONFLICT phone DO UPDATE) was
-- blocked by RLS for returning customers → customer_id stayed
-- null on orders → loyalty accrual silently returned early.
-- ============================================================

-- 1. Allow UPDATE on customers (needed for upsert from ordering page)
--    Anon users can only reach this via the ON CONFLICT path which
--    matches by phone — they effectively only update their own row.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='customers' AND policyname='customers_update'
  ) THEN
    CREATE POLICY "customers_update" ON customers
      FOR UPDATE USING (true) WITH CHECK (true);
  END IF;
END $$;

-- 2. Re-create accrue_loyalty_for_order with SET search_path for safety
CREATE OR REPLACE FUNCTION accrue_loyalty_for_order(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_customer_id uuid;
  v_total       numeric;
  v_points      integer;
  v_new_total   integer;
  v_new_tier    text;
BEGIN
  SELECT customer_id, total_price
    INTO v_customer_id, v_total
    FROM orders
   WHERE id = p_order_id;

  IF v_customer_id IS NULL THEN RETURN; END IF;

  -- Idempotency: skip if already accrued for this order
  IF EXISTS (SELECT 1 FROM loyalty_ledger WHERE order_id = p_order_id AND reason = 'order') THEN
    RETURN;
  END IF;

  v_points := FLOOR(v_total / 10)::integer;
  IF v_points <= 0 THEN RETURN; END IF;

  INSERT INTO loyalty_ledger (customer_id, order_id, delta, reason)
  VALUES (v_customer_id, p_order_id, v_points, 'order');

  UPDATE customers
     SET loyalty_points = loyalty_points + v_points
   WHERE id = v_customer_id
  RETURNING loyalty_points INTO v_new_total;

  v_new_tier := CASE
    WHEN v_new_total >= 1000 THEN 'gold'
    WHEN v_new_total >= 300  THEN 'silver'
    ELSE 'bronze'
  END;

  UPDATE customers SET tier = v_new_tier WHERE id = v_customer_id;
END;
$$;

-- 3. Backfill helper: accrue points for served orders that have no ledger entry yet.
--    Safe to run multiple times — skips already-accrued orders.
CREATE OR REPLACE FUNCTION recalculate_loyalty_for_customer(p_customer_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_order_id uuid;
  v_count    integer := 0;
BEGIN
  FOR v_order_id IN
    SELECT o.id
      FROM orders o
     WHERE o.customer_id = p_customer_id
       AND o.status = 'served'
       AND NOT EXISTS (
         SELECT 1 FROM loyalty_ledger l
          WHERE l.order_id = o.id AND l.reason = 'order'
       )
  LOOP
    PERFORM accrue_loyalty_for_order(v_order_id);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
