-- ============================================================
-- Glongnom POS — Phase 3 CRM Migration
-- Adds loyalty program, ledger, and accrual functions
-- ============================================================

-- ── Extend customers table ──
ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS loyalty_points integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tier           text    DEFAULT 'bronze'
    CHECK (tier IN ('bronze', 'silver', 'gold')),
  ADD COLUMN IF NOT EXISTS birthday       date,
  ADD COLUMN IF NOT EXISTS notes          text;

-- ── Loyalty ledger ──
CREATE TABLE IF NOT EXISTS public.loyalty_ledger (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id uuid        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  order_id    uuid        REFERENCES orders(id) ON DELETE SET NULL,
  delta       integer     NOT NULL,   -- positive = earn, negative = manual deduct
  reason      text        NOT NULL DEFAULT 'order',  -- 'order' | 'manual' | 'birthday'
  note        text,
  created_at  timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS loyalty_ledger_customer_idx ON loyalty_ledger(customer_id);

ALTER TABLE loyalty_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "loyalty_ledger_read"  ON loyalty_ledger FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "loyalty_ledger_write" ON loyalty_ledger FOR ALL
  USING (EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND role IN ('admin','manager','cashier')
  ));

-- ── Loyalty accrual function (called when order → served) ──
CREATE OR REPLACE FUNCTION accrue_loyalty_for_order(p_order_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_customer_id uuid;
  v_total       numeric;
  v_points      integer;
  v_new_total   integer;
  v_new_tier    text;
BEGIN
  -- Get order info
  SELECT customer_id, total_price
    INTO v_customer_id, v_total
    FROM orders
   WHERE id = p_order_id;

  -- Only accrue if there is a customer linked
  IF v_customer_id IS NULL THEN RETURN; END IF;

  -- Already accrued? Idempotency check via ledger
  IF EXISTS (SELECT 1 FROM loyalty_ledger WHERE order_id = p_order_id AND reason = 'order') THEN
    RETURN;
  END IF;

  -- Calculate points: floor(total / 10)
  v_points := FLOOR(v_total / 10)::integer;
  IF v_points <= 0 THEN RETURN; END IF;

  -- Insert ledger entry
  INSERT INTO loyalty_ledger (customer_id, order_id, delta, reason)
  VALUES (v_customer_id, p_order_id, v_points, 'order');

  -- Update customer points
  UPDATE customers
     SET loyalty_points = loyalty_points + v_points
   WHERE id = v_customer_id
  RETURNING loyalty_points INTO v_new_total;

  -- Recalculate tier
  v_new_tier := CASE
    WHEN v_new_total >= 1000 THEN 'gold'
    WHEN v_new_total >= 300  THEN 'silver'
    ELSE 'bronze'
  END;

  UPDATE customers SET tier = v_new_tier WHERE id = v_customer_id;
END;
$$;

-- ── Manual loyalty adjustment function ──
CREATE OR REPLACE FUNCTION adjust_loyalty_points(
  p_customer_id uuid,
  p_delta       integer,
  p_reason      text,
  p_note        text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_total integer;
  v_new_tier  text;
BEGIN
  -- Insert ledger entry
  INSERT INTO loyalty_ledger (customer_id, delta, reason, note)
  VALUES (p_customer_id, p_delta, p_reason, p_note);

  -- Update customer points (floor at 0)
  UPDATE customers
     SET loyalty_points = GREATEST(0, loyalty_points + p_delta)
   WHERE id = p_customer_id
  RETURNING loyalty_points INTO v_new_total;

  -- Recalculate tier
  v_new_tier := CASE
    WHEN v_new_total >= 1000 THEN 'gold'
    WHEN v_new_total >= 300  THEN 'silver'
    ELSE 'bronze'
  END;

  UPDATE customers SET tier = v_new_tier WHERE id = p_customer_id;
END;
$$;
