-- ============================================================
-- Migration 019: Add accounting_entries to Realtime publication
-- accounting_entries was never added to supabase_realtime, so
-- the Realtime subscription in accounting.html received nothing.
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE accounting_entries;

-- Re-grant execute to be safe (idempotent)
GRANT EXECUTE ON FUNCTION public.record_order_income     TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_purchase_expense TO authenticated;
