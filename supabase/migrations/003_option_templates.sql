-- ============================================================
-- Glongnom POS — Option Template System
-- Replaces per-menu option_groups with reusable global templates
-- Run AFTER 002_seed_menu.sql
-- ============================================================

-- ---- New Tables ----

create table option_templates (
  id          uuid primary key default uuid_generate_v4(),
  shop_id     uuid references shops(id),
  name        text not null,
  name_th     text,
  is_required boolean default true,
  sort_order  int default 0,
  created_at  timestamptz default now()
);

create table option_template_choices (
  id               uuid primary key default uuid_generate_v4(),
  template_id      uuid references option_templates(id) on delete cascade,
  name             text not null,
  name_th          text,
  additional_price numeric(10,2) default 0,
  sort_order       int default 0
);

create table menu_option_templates (
  menu_id     uuid references menus(id) on delete cascade,
  template_id uuid references option_templates(id) on delete cascade,
  sort_order  int default 0,
  primary key (menu_id, template_id)
);

-- ---- RLS ----

alter table option_templates        enable row level security;
alter table option_template_choices enable row level security;
alter table menu_option_templates   enable row level security;

create policy "opt_templates_public_read"   on option_templates        for select using (true);
create policy "opt_templates_admin_write"   on option_templates        for all    using (current_user_role() in ('admin','manager'));
create policy "opt_choices_public_read"     on option_template_choices for select using (true);
create policy "opt_choices_admin_write"     on option_template_choices for all    using (current_user_role() in ('admin','manager'));
create policy "menu_opt_templates_read"     on menu_option_templates   for select using (true);
create policy "menu_opt_templates_admin"    on menu_option_templates   for all    using (current_user_role() in ('admin','manager'));

-- ---- Migrate existing option_groups data → templates ----

do $$
declare
  v_shop_id   uuid;
  v_tmpl_id   uuid;
  r_group     record;
  r_choice    record;
  r_assign    record;
begin
  select id into v_shop_id from shops where branch_code = 'GLN-01';

  -- Insert one template per distinct option group name
  for r_group in (
    select distinct on (name) name, name_th, is_required, sort_order
    from option_groups
    order by name, sort_order
  ) loop
    insert into option_templates (shop_id, name, name_th, is_required, sort_order)
    values (v_shop_id, r_group.name, r_group.name_th, r_group.is_required, r_group.sort_order)
    returning id into v_tmpl_id;

    -- Insert distinct choices for this template
    for r_choice in (
      select distinct on (oc.name)
        oc.name, oc.name_th, oc.additional_price, oc.sort_order
      from option_choices oc
      join option_groups og on og.id = oc.group_id
      where og.name = r_group.name
      order by oc.name, oc.sort_order
    ) loop
      insert into option_template_choices
        (template_id, name, name_th, additional_price, sort_order)
      values
        (v_tmpl_id, r_choice.name, r_choice.name_th, r_choice.additional_price, r_choice.sort_order);
    end loop;
  end loop;

  -- Assign templates to menus based on existing option_groups
  for r_assign in (
    select distinct og.menu_id, ot.id as template_id, og.sort_order
    from option_groups og
    join option_templates ot on ot.name = og.name
  ) loop
    insert into menu_option_templates (menu_id, template_id, sort_order)
    values (r_assign.menu_id, r_assign.template_id, r_assign.sort_order)
    on conflict (menu_id, template_id) do nothing;
  end loop;

end;
$$;

-- ---- Realtime for admin live updates ----
alter publication supabase_realtime add table option_templates;
alter publication supabase_realtime add table menu_option_templates;
