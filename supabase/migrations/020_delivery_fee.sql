-- Add delivery_fee to shops so admin can configure it per-branch
ALTER TABLE shops
  ADD COLUMN IF NOT EXISTS delivery_fee numeric(10,2) DEFAULT 10 NOT NULL;

-- Snapshot the fee at order-time so historical records stay accurate
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_fee numeric(10,2) DEFAULT 0 NOT NULL;
