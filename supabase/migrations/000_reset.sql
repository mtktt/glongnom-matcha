-- ============================================================
-- RESET — drops all Glongnom POS tables and functions
-- Run this FIRST if you hit "relation already exists" errors.
-- Then run 001_initial_schema.sql to recreate everything fresh.
-- ============================================================

-- Drop tables in reverse dependency order (children before parents)
drop table if exists kitchen_queue        cascade;
drop table if exists order_item_options   cascade;
drop table if exists order_items          cascade;
drop table if exists orders               cascade;
drop table if exists customers            cascade;
drop table if exists option_choices       cascade;
drop table if exists option_groups        cascade;
drop table if exists menus                cascade;
drop table if exists categories           cascade;
drop table if exists user_profiles        cascade;
drop table if exists shops                cascade;

-- Drop sequence
drop sequence if exists order_no_seq;

-- Drop functions (cascade removes dependent triggers automatically)
drop function if exists handle_new_user()    cascade;
drop function if exists set_updated_at()     cascade;
drop function if exists current_user_role()  cascade;
