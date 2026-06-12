-- Allow authenticated users to read customers (needed for dashboard, reports, CRM)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='customers' AND policyname='customers_authenticated_read'
  ) THEN
    CREATE POLICY "customers_authenticated_read" ON customers
      FOR SELECT USING (auth.uid() IS NOT NULL);
  END IF;
END $$;
