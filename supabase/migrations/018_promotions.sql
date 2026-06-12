-- ============================================================
-- Glongnom POS — Migration 018: Promotions
-- Two promo types:
--   item_discount — one or more menus discounted by % or fixed ฿
--   bundle        — order all items in set → get bundle_price
-- ============================================================

-- ── 1. Promotions table ──────────────────────────────────────
CREATE TABLE public.promotions (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  shop_id        uuid REFERENCES shops(id) ON DELETE CASCADE,
  name           text NOT NULL,
  name_th        text,
  promo_type     text NOT NULL CHECK (promo_type IN ('item_discount', 'bundle')),
  discount_type  text CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value numeric CHECK (discount_value IS NULL OR discount_value > 0),
  bundle_price   numeric CHECK (bundle_price IS NULL OR bundle_price > 0),
  description    text,
  start_date     date,
  end_date       date,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz DEFAULT now(),

  -- item_discount must have discount_type + value
  CONSTRAINT promo_item_discount_fields CHECK (
    promo_type <> 'item_discount' OR (discount_type IS NOT NULL AND discount_value IS NOT NULL)
  ),
  -- bundle must have bundle_price
  CONSTRAINT promo_bundle_fields CHECK (
    promo_type <> 'bundle' OR bundle_price IS NOT NULL
  )
);

-- ── 2. Promotion items (menus in each promo) ─────────────────
CREATE TABLE public.promotion_items (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  promotion_id uuid NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  menu_id      uuid NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
  UNIQUE (promotion_id, menu_id)
);

-- ── 3. Track discount on orders ──────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS discount_amount numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS promotion_id    uuid REFERENCES promotions(id) ON DELETE SET NULL;

-- ── 4. Indexes ───────────────────────────────────────────────
CREATE INDEX ON public.promotions (shop_id, is_active);
CREATE INDEX ON public.promotion_items (promotion_id);
CREATE INDEX ON public.promotion_items (menu_id);

-- ── 5. RLS ───────────────────────────────────────────────────
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotion_items ENABLE ROW LEVEL SECURITY;

-- Public read: customers need to load active promos
CREATE POLICY "promos_public_read"  ON public.promotions FOR SELECT USING (true);
CREATE POLICY "promos_admin_insert" ON public.promotions FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager')));
CREATE POLICY "promos_admin_update" ON public.promotions FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager')));
CREATE POLICY "promos_admin_delete" ON public.promotions FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager')));

CREATE POLICY "promo_items_public_read" ON public.promotion_items FOR SELECT USING (true);
CREATE POLICY "promo_items_admin_write" ON public.promotion_items FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager')))
  WITH CHECK (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin','manager')));
