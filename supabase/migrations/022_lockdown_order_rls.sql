-- ============================================================
-- Glongnom POS — Migration 022: Lock down direct order writes
-- ============================================================
-- ⚠️  RUN THIS ONLY AFTER you have run 021 AND verified that placing
--     an order through the customer app works end-to-end.
--
-- WHY
-- Migration 021 added create_order(), which validates and writes orders
-- server-side. But the old permissive RLS policies are still in place:
--
--   orders_insert              with check (true)
--   order_items_insert         with check (true)
--   order_item_options_insert  with check (true)
--   customers_insert           with check (true)
--
-- As long as those exist, a malicious client can STILL bypass the RPC and
-- insert a fake-priced order directly with the anon key. This migration
-- removes them, so the SECURITY DEFINER function (which runs as the table
-- owner and bypasses RLS) becomes the ONLY way to create an order.
--
-- Staff read/update policies on orders are UNTOUCHED — the kitchen queue,
-- mark-paid, status changes, etc. all keep working.
--
-- ROLLBACK: if something breaks, re-create the dropped policies (the
-- original definitions are reproduced at the bottom of this file, commented
-- out) to restore the previous behavior while you debug.
-- ============================================================

-- --- Close the INSERT hole (price tampering — finding A1) ---
DROP POLICY IF EXISTS "orders_insert"             ON public.orders;
DROP POLICY IF EXISTS "order_items_insert"        ON public.order_items;
DROP POLICY IF EXISTS "order_item_options_insert" ON public.order_item_options;
DROP POLICY IF EXISTS "customers_insert"          ON public.customers;

-- --- Close the READ leak (customer PII — found during the 2026-06-12 ---
-- --- live anon-key test: anyone could read every order's name/phone/  ---
-- --- address). These permissive `using (true)` SELECT policies were   ---
-- --- added as manual SQL during the Phase 1A Bug #4 fix. The customer ---
-- --- app no longer needs them: create_order() returns the confirmation---
-- --- data directly, so anon never reads these tables. Staff reads keep---
-- --- working via the role-gated *_staff_read policies from migration  ---
-- --- 001. (IF EXISTS makes each drop a safe no-op if absent.)         ---
DROP POLICY IF EXISTS "orders_read_own"            ON public.orders;
DROP POLICY IF EXISTS "order_items_read"           ON public.order_items;
DROP POLICY IF EXISTS "order_item_options_read"    ON public.order_item_options;

-- ------------------------------------------------------------
-- ROLLBACK (uncomment and run to restore the old open inserts):
--
-- CREATE POLICY "orders_insert"             ON public.orders             FOR INSERT WITH CHECK (true);
-- CREATE POLICY "order_items_insert"        ON public.order_items        FOR INSERT WITH CHECK (true);
-- CREATE POLICY "order_item_options_insert" ON public.order_item_options FOR INSERT WITH CHECK (true);
-- CREATE POLICY "customers_insert"          ON public.customers          FOR INSERT WITH CHECK (true);
-- CREATE POLICY "orders_read_own"           ON public.orders             FOR SELECT USING (true);
-- CREATE POLICY "order_items_read"          ON public.order_items        FOR SELECT USING (true);
-- CREATE POLICY "order_item_options_read"   ON public.order_item_options FOR SELECT USING (true);
-- ------------------------------------------------------------
