-- ============================================================
-- Glongnom POS — Phase 1A Initial Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- SHOP CONFIG
-- ============================================================
create table shops (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  branch_code     text unique,
  address         text,
  phone           text,
  opening_hours   jsonb default '{}',
  is_open         boolean default true,
  tax_rate        numeric(5,2) default 0,
  payment_enabled boolean default false,   -- PromptPay QR: flip to true when ready
  line_notify_token text,
  created_at      timestamptz default now()
);

-- Seed one default shop row
insert into shops (name, branch_code, is_open, payment_enabled)
values ('Glongnom Matcha', 'GLN-01', true, false);

-- ============================================================
-- USER PROFILES (extends Supabase auth.users)
-- ============================================================
create table user_profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text,
  role        text not null default 'staff'
                check (role in ('admin','manager','cashier','kitchen','staff')),
  shop_id     uuid references shops(id),
  is_active   boolean default true,
  created_at  timestamptz default now()
);

-- Auto-create profile row when a new auth user is created
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into user_profiles (id, name)
  values (new.id, new.email);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ============================================================
-- CATEGORIES
-- ============================================================
create table categories (
  id          uuid primary key default uuid_generate_v4(),
  shop_id     uuid references shops(id),
  name        text not null,
  name_th     text,
  sort_order  int default 0,
  is_active   boolean default true,
  created_at  timestamptz default now()
);

insert into categories (shop_id, name, name_th, sort_order)
select id, 'Matcha',  'มัทฉะ',   1 from shops where branch_code = 'GLN-01' union all
select id, 'Drinks',  'เครื่องดื่ม', 2 from shops where branch_code = 'GLN-01' union all
select id, 'Rice',    'ข้าว',    3 from shops where branch_code = 'GLN-01';

-- ============================================================
-- MENU ITEMS
-- ============================================================
create table menus (
  id          uuid primary key default uuid_generate_v4(),
  shop_id     uuid references shops(id),
  category_id uuid references categories(id),
  name        text not null,
  name_th     text,
  description text,
  description_th text,
  base_price  numeric(10,2) not null default 0,
  image_url   text,
  is_active   boolean default true,
  sort_order  int default 0,
  created_at  timestamptz default now()
);

-- ============================================================
-- OPTION GROUPS (e.g. "Sweetness", "Ice Level")
-- ============================================================
create table option_groups (
  id          uuid primary key default uuid_generate_v4(),
  menu_id     uuid references menus(id) on delete cascade,
  name        text not null,
  name_th     text,
  is_required boolean default false,
  sort_order  int default 0
);

-- ============================================================
-- OPTION CHOICES (e.g. "Low", "Medium", "High")
-- ============================================================
create table option_choices (
  id                uuid primary key default uuid_generate_v4(),
  group_id          uuid references option_groups(id) on delete cascade,
  name              text not null,
  name_th           text,
  additional_price  numeric(10,2) default 0,
  sort_order        int default 0
);

-- ============================================================
-- CUSTOMERS
-- ============================================================
create table customers (
  id            uuid primary key default uuid_generate_v4(),
  name          text,
  phone         text unique,
  address       text,
  line_user_id  text,
  created_at    timestamptz default now()
);

-- ============================================================
-- ORDERS
-- ============================================================
create sequence order_no_seq start 1001;

create table orders (
  id              uuid primary key default uuid_generate_v4(),
  order_no        text unique default ('ORD-' || nextval('order_no_seq')::text),
  shop_id         uuid references shops(id),
  customer_id     uuid references customers(id),
  customer_name   text,   -- snapshot at order time (customer may be guest)
  customer_phone  text,
  customer_address text,
  order_type      text default 'delivery'
                    check (order_type in ('delivery','pickup','dine_in')),
  table_no        text,
  status          text default 'new'
                    check (status in ('new','preparing','ready','served','cancelled')),
  payment_status  text default 'pending'
                    check (payment_status in ('pending','paid','refunded')),
  payment_slip_url text,  -- Supabase Storage URL of uploaded slip
  subtotal        numeric(10,2) default 0,
  delivery_fee    numeric(10,2) default 0,
  total_price     numeric(10,2) default 0,
  note            text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Auto-update updated_at on any row change
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger orders_updated_at
  before update on orders
  for each row execute procedure set_updated_at();

-- ============================================================
-- ORDER ITEMS
-- ============================================================
create table order_items (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid references orders(id) on delete cascade,
  menu_id     uuid references menus(id),
  menu_name   text,                -- snapshot at order time
  qty         int not null default 1,
  unit_price  numeric(10,2) not null,
  note        text,
  created_at  timestamptz default now()
);

-- ============================================================
-- ORDER ITEM OPTIONS (snapshot of chosen options)
-- ============================================================
create table order_item_options (
  id                uuid primary key default uuid_generate_v4(),
  order_item_id     uuid references order_items(id) on delete cascade,
  choice_id         uuid references option_choices(id),
  group_name        text,   -- snapshot
  choice_name       text,   -- snapshot
  additional_price  numeric(10,2) default 0  -- snapshot
);

-- ============================================================
-- KITCHEN QUEUE
-- ============================================================
create table kitchen_queue (
  id            uuid primary key default uuid_generate_v4(),
  order_id      uuid references orders(id) on delete cascade,
  order_item_id uuid references order_items(id) on delete cascade,
  station       text default 'main',
  status        text default 'pending'
                  check (status in ('pending','preparing','ready')),
  started_at    timestamptz,
  completed_at  timestamptz
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
alter table shops               enable row level security;
alter table user_profiles       enable row level security;
alter table categories          enable row level security;
alter table menus               enable row level security;
alter table option_groups       enable row level security;
alter table option_choices      enable row level security;
alter table customers           enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table order_item_options  enable row level security;
alter table kitchen_queue       enable row level security;

-- Helper: get current user's role
create or replace function current_user_role()
returns text language sql security definer stable as $$
  select role from user_profiles where id = auth.uid()
$$;

-- ---- SHOPS: public read, admin/manager write ----
create policy "shops_public_read"  on shops for select using (true);
create policy "shops_admin_write"  on shops for all
  using (current_user_role() in ('admin','manager'));

-- ---- USER PROFILES: own row only (+ admin sees all) ----
create policy "profiles_own_row" on user_profiles for select
  using (id = auth.uid() or current_user_role() = 'admin');
create policy "profiles_own_update" on user_profiles for update
  using (id = auth.uid() or current_user_role() = 'admin');

-- ---- CATEGORIES: public read, admin/manager write ----
create policy "categories_public_read" on categories for select using (true);
create policy "categories_admin_write" on categories for all
  using (current_user_role() in ('admin','manager'));

-- ---- MENUS: public read, admin/manager write ----
create policy "menus_public_read" on menus for select using (true);
create policy "menus_admin_write" on menus for all
  using (current_user_role() in ('admin','manager'));

-- ---- OPTION GROUPS + CHOICES: public read, admin/manager write ----
create policy "option_groups_public_read" on option_groups for select using (true);
create policy "option_groups_admin_write" on option_groups for all
  using (current_user_role() in ('admin','manager'));
create policy "option_choices_public_read" on option_choices for select using (true);
create policy "option_choices_admin_write" on option_choices for all
  using (current_user_role() in ('admin','manager'));

-- ---- CUSTOMERS: anyone can insert (guest checkout), admin/manager read all ----
create policy "customers_insert" on customers for insert with check (true);
create policy "customers_admin_read" on customers for select
  using (current_user_role() in ('admin','manager','cashier'));

-- ---- ORDERS: anyone can insert (guest checkout), staff can read/update ----
create policy "orders_insert" on orders for insert with check (true);
create policy "orders_staff_read" on orders for select
  using (
    current_user_role() in ('admin','manager','cashier','kitchen')
  );
create policy "orders_staff_update" on orders for update
  using (current_user_role() in ('admin','manager','cashier','kitchen'));

-- ---- ORDER ITEMS: same as orders ----
create policy "order_items_insert" on order_items for insert with check (true);
create policy "order_items_staff_read" on order_items for select
  using (current_user_role() in ('admin','manager','cashier','kitchen'));

-- ---- ORDER ITEM OPTIONS: same as orders ----
create policy "order_item_options_insert" on order_item_options for insert with check (true);
create policy "order_item_options_staff_read" on order_item_options for select
  using (current_user_role() in ('admin','manager','cashier','kitchen'));

-- ---- KITCHEN QUEUE: kitchen + above can read/update ----
create policy "kitchen_queue_staff_read" on kitchen_queue for select
  using (current_user_role() in ('admin','manager','cashier','kitchen'));
create policy "kitchen_queue_insert" on kitchen_queue for insert with check (true);
create policy "kitchen_queue_kitchen_update" on kitchen_queue for update
  using (current_user_role() in ('admin','manager','kitchen'));

-- ============================================================
-- REALTIME: enable for order live updates and KDS
-- ============================================================
alter publication supabase_realtime add table orders;
alter publication supabase_realtime add table order_items;
alter publication supabase_realtime add table kitchen_queue;
