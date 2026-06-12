# Glongnom POS — Session Update Log
**Session Date:** 2026-05-28 / 2026-05-29
**Phase Completed:** Phase 1A — Core POS Loop + Post-launch Improvements

---

## Phase 1A Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Project folder structure | `js/`, `css/`, `admin/`, `kitchen/`, `supabase/migrations/`, `netlify/functions/` |
| 2 | Database schema + RLS + Realtime | `supabase/migrations/001_initial_schema.sql` |
| 3 | Database reset script | `supabase/migrations/000_reset.sql` |
| 4 | Menu seed data (22 items, 6 option groups) | `supabase/migrations/002_seed_menu.sql` |
| 5 | Supabase client config | `js/config.js` |
| 6 | Auth system — login, session, role guard | `login.html`, `js/auth.js` |
| 7 | Password set/reset page | `reset-password.html` |
| 8 | Admin panel — menu CRUD, shop toggle, close message | `admin/index.html` |
| 9 | Order queue — live Supabase Realtime | `admin/orders.html` |
| 10 | Customer ordering app — ported GAS → Supabase | `index.html` |
| 11 | PromptPay QR (built, disabled by flag) | `js/promptpay.js` |
| 12 | LINE notification — Netlify Function + Supabase Webhook | `netlify/functions/line-notify.js` |
| 13 | Netlify deployment config | `netlify.toml` |
| 14 | Roadmap updated — tech stack, Phase 1A/1B split | `roadmap.md` |

**Live URL:** https://glongnom-pos.netlify.app

---

## Post-launch Features Added (Same Session)

| # | Feature | Files Changed |
|---|---|---|
| 15 | Drag & drop menu sorting (global sort_order) | `admin/index.html` |
| 16 | Permanent delete with confirmation modal | `admin/index.html` |
| 17 | Disable/Enable button color (yellow/green) | `admin/index.html` |
| 18 | Edit close message when closing shop | `admin/index.html`, SQL alter shops |
| 19 | Self-service Forgot Password on login page | `login.html` |
| 20 | User Management page — invite, change role, deactivate | `admin/users.html` |
| 21 | Netlify Function — invite staff via Supabase Admin API | `netlify/functions/invite-user.js` |
| 22 | Option Template System — reusable global option groups | `supabase/migrations/003_option_templates.sql` |
| 23 | Option Groups admin page — CRUD templates + choices | `admin/options.html` |
| 24 | Assign Options modal per menu item | `admin/index.html` |
| 25 | Customer ordering app updated to use template query | `index.html` |

---

## Tech Stack (Locked)

| Layer | Tool |
|---|---|
| Database + Auth + Realtime | Supabase (PostgreSQL) |
| Frontend | Vanilla JS |
| Hosting | Netlify |
| Serverless Functions | Netlify Functions (Node 18) |
| Notifications | LINE Messaging API via Netlify Function |

---

## Bugs & Fixes

| # | Bug | Cause | Solution |
|---|---|---|---|
| 1 | `relation "shops" already exists` | Schema run twice — first run failed mid-way, left partial tables | Created `000_reset.sql` to drop all tables cleanly before re-running schema |
| 2 | `relation "drink" does not exist` | Unicode `×` chars in SQL comments confused Supabase's RLS advisor — clicking "Enable RLS" tried to run `ALTER TABLE drink` | Removed all `×` chars from SQL comments, always click "Run anyway" on RLS warning |
| 3 | `Identifier 'supabase' has already been declared` | Supabase CDN sets `window.supabase` as namespace; `config.js` tried to re-declare `const supabase` in same global scope | Changed `const supabase =` → `window.supabase =` in `config.js` |
| 4 | `new row violates row-level security policy for table "orders"` | INSERT + `.select()` chained requires both INSERT and SELECT policy — anon had no SELECT policy | Added SELECT policies for orders, order_items, order_item_options with `using (true)` |
| 5 | Invite email link pointed to `localhost` | Supabase Site URL not configured — defaults to localhost | Set Site URL to Netlify URL, created `reset-password.html`, re-sent invite |
| 6 | `Database error saving new user` on invite | `handle_new_user` trigger couldn't find `user_profiles` without explicit search_path | Added `set search_path = public` to trigger function |
| 7 | Menu not loading on Netlify | Netlify Functions defaulted to Node 16 — no built-in `fetch` | Added `NODE_VERSION = "18"` to `netlify.toml` |
| 8 | Drag & drop sort not persisting on ordering page | sort_order saved per-category causing global overlaps (Matcha 1-13, Drinks 1-7) | Fixed `onDrop` to always reassign sort_order across ALL items globally |
| 9 | SUPABASE_URL secret env var broke redeploy | Netlify "secret" vars behave differently during build phase | Changed to plain env var — only `LINE_CHANNEL_TOKEN` and `WEBHOOK_SECRET` need to be secret |
| 10 | `invite-user.js` deploy error — could not resolve `@supabase/supabase-js` | No `package.json` in project — esbuild can't bundle npm package | Rewrote function using native `fetch` only, no npm dependencies |

---

## Feature Requests & Implementation

| # | Request | Solution |
|---|---|---|
| 1 | Drag & drop menu sorting | HTML5 drag events → save global sort_order to Supabase on drop |
| 2 | Permanent delete with confirmation | Delete button → confirm modal with item name → `supabase.delete()` with FK error handled |
| 3 | Disable/Enable button color differentiation | Disable = yellow, Enable = green, Delete = red |
| 4 | Edit close message when closing shop | `close_message` column on shops + Close Shop modal with editable textarea |
| 5 | LINE message format match original GAS | Rewrote `line-notify.js` to match `code_new.gs` format exactly |
| 6 | Self-service forgot password for staff | `supabase.auth.resetPasswordForEmail()` with `redirectTo: reset-password.html` |
| 7 | Add new users without Supabase dashboard | `admin/users.html` + `invite-user.js` Netlify Function using Supabase Admin API |
| 8 | Option group management (Lineman/Wongnai style) | New Option Template System: global reusable groups + assign to menus |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `000_reset.sql` | Drop all tables (use when re-running schema) |
| `001_initial_schema.sql` | All core tables, RLS, Realtime, seed shop + categories |
| `002_seed_menu.sql` | 22 menu items + 6 option groups seeded |
| `003_option_templates.sql` | Option Template System tables + migrate old data |

---

## Manual SQL Applied (Not in Migration Files)

```sql
-- Fix handle_new_user trigger
create or replace function handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.user_profiles (id, name) values (new.id, new.email);
  return new;
end; $$;

-- RLS fix for guest order submission
create policy "orders_insert"             on orders             for insert with check (true);
create policy "orders_read_own"           on orders             for select using (true);
create policy "order_items_insert"        on order_items        for insert with check (true);
create policy "order_items_read"          on order_items        for select using (true);
create policy "order_item_options_insert" on order_item_options for insert with check (true);
create policy "order_item_options_read"   on order_item_options for select using (true);
create policy "customers_insert"          on customers          for insert with check (true);

-- Close message column
alter table shops add column if not exists close_message text
  default 'ขณะนี้ร้านปิดรับออร์เดอร์ค่ะ ^^';
```

---

## Supabase Configuration (Reference)

| Setting | Value |
|---|---|
| Project URL | `https://ykxzmakquyjpsgdaalba.supabase.co` |
| Site URL | `https://glongnom-pos.netlify.app` |
| Redirect URLs | `https://glongnom-pos.netlify.app/reset-password.html` |
| Database Webhook | INSERT on `orders` → `/.netlify/functions/line-notify` with `x-webhook-secret` header |

---

## Netlify Environment Variables

| Variable | Type | Purpose |
|---|---|---|
| `LINE_CHANNEL_TOKEN` | Secret | LINE Messaging API push |
| `WEBHOOK_SECRET` | Secret | Verify Supabase webhook requests |
| `SUPABASE_URL` | Plain | Supabase project URL |
| `SUPABASE_ANON_KEY` | Plain | Supabase anon key |
| `SUPABASE_SERVICE_KEY` | Secret | Admin API for user invitations |
| `LINE_USER_ID` | Plain | Owner's LINE user ID |
| `SITE_URL` | Plain | `https://glongnom-pos.netlify.app` |

---

## Admin Panel Pages

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort | admin, manager |
| `/admin/orders.html` | Live order queue | admin, manager, cashier |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/login.html` | Staff login + forgot password | — |
| `/reset-password.html` | Set/reset password from email link | — |

---

## Next Phase

**Phase 1B — Kitchen & Hardware Layer**
- Kitchen Display System (KDS) using Supabase Realtime → `kitchen/index.html`
- Browser PDF receipt for customer and kitchen
- ESC/POS thermal printer (stretch goal)

**Phase 2 — Inventory & Costing**
- BOM/recipe engine (auto-deduct ingredients per order)
- Supplier + purchase order management
- Low-stock alerts

---

---

# Design System Alignment & UI/UX Overhaul
**Session Date:** 2026-05-29
**Scope:** All 6 admin/auth pages + global design system infrastructure

---

## Task 1 — Design System Alignment

Applied the design system established in `index.html` to all 6 previously unstyled files.

| Task | Files Affected |
|---|---|
| Created CSS variable `:root` block | All 6 files |
| Added Sarabun (Google Fonts) | All 6 files |
| Replaced green scheme (`#4a7c59`) with brown/pink brand palette | `login.html`, `reset-password.html`, all 4 admin pages |
| Fixed button styles — pill radius, `var(--brown-dark)`/`var(--brown-mid)` | All 6 files |
| Fixed input focus styles — `var(--pink-deep)` + pink glow | All 6 files |
| Fixed card/surface styles — `var(--surface-warm)`, brown shadows, `var(--radius-lg)` | All 6 files |

---

## Task 2 — Login & Reset Password

| # | Improvement | Files |
|---|---|---|
| 1 | Pink brand divider added below `<h1>` | `login.html`, `reset-password.html` |
| 2 | Body repositioned to golden-third vertical placement (`clamp(64px, 12vh, 140px)` top padding) | `login.html`, `reset-password.html` |
| 3 | Animated Login ↔ Forgot Password panel switch — opacity + translateY fade, removed `display:none` jump | `login.html` |
| 4 | Password show/hide toggle (`👁`) added to all password fields | `login.html`, `reset-password.html` |
| 5 | "← Back to login" link added | `reset-password.html` |
| 6 | Disappearing placeholder replaced with persistent "Minimum 6 characters" hint text | `reset-password.html` |

---

## Task 3 — Admin Menu Management

| # | Improvement | Files |
|---|---|---|
| 1 | Shop Open/Close toggle separated from Sign Out with visual border; `●`/`○` prefix + tooltip | `admin/index.html` |
| 2 | Mobile hamburger nav — collapses to `☰` below 640px (later superseded by sidebar in Phase 7) | `admin/index.html` |
| 3 | 4-button action column replaced with Edit + `•••` overflow dropdown (Options / Disable / Delete) | `admin/index.html` |
| 4 | Active / Inactive / Total count summary bar above table, live-updating | `admin/index.html` |
| 5 | Live image URL preview (64×64px) in Add/Edit modal — auto-hides on broken URL | `admin/index.html` |
| 6 | Drag handle upgraded from Braille `⠿` to 6-dot grip SVG + first-use dismissable banner | `admin/index.html` |

---

## Task 4 — Orders Page

| # | Improvement | Files |
|---|---|---|
| 1 | Color-coded column headers — amber left border (New), pink (Preparing), green (Ready) | `admin/orders.html` |
| 2 | "New" badge turns amber/urgent when count > 0 | `admin/orders.html` |
| 3 | Age badges on New orders: green <5 min, amber 5–10 min, red >10 min; auto-refreshes every 60 s | `admin/orders.html` |
| 4 | Order item rows split into bold name + muted options on separate lines with left border grouping | `admin/orders.html` |
| 5 | "Mark Paid" demoted to ghost-style button | `admin/orders.html` |
| 6 | Empty "New" column shows "✓ All quiet / No new orders" placeholder | `admin/orders.html` |
| 7 | Past order search bar — queries by order number or customer name, shows styled result cards | `admin/orders.html` |

---

## Task 5 — Options Page

| # | Improvement | Files |
|---|---|---|
| 1 | Add-choice row inputs have persistent `NAME EN`, `NAME TH`, `PRICE +฿` labels | `admin/options.html` |
| 2 | Choice rows are drag-to-reorder with 6-dot grip SVG; updates `sort_order` in Supabase on drop | `admin/options.html` |
| 3 | Template card headers have `tabindex="0"`, `role="button"`, keyboard support (Enter/Space), `aria-expanded` | `admin/options.html` |
| 4 | Delete confirmation modal shows which menus will be unassigned | `admin/options.html` |
| 5 | "Assigned to menus" section moved from bottom to top of choices panel | `admin/options.html` |

---

## Task 6 — Users Page

| # | Improvement | Files |
|---|---|---|
| 1 | Deactivate/Activate buttons use `.btn-deactivate`/`.btn-activate` CSS classes — removed inline styles | `admin/users.html` |
| 2 | Email column added to the users table | `admin/users.html` |
| 3 | Confirmation dialog before deactivating a user ("They will lose access immediately.") | `admin/users.html` |
| 4 | Admin badge changed to solid dark purple (`#7c3aed`, white text) to signal higher privilege | `admin/users.html` |
| 5 | Current user's row highlighted in `var(--pink-soft)`; inline "(You)" marker in pink; tooltip on disabled button | `admin/users.html` |

---

## Task 7 — Left Sidebar Navigation

Replaced the top `<nav>` bar on all 4 admin pages with a left slide-over sidebar pattern.

| Element | Detail |
|---|---|
| Trigger bar | Fixed 52px bar — hamburger + brand name + current page label + shop toggle (menu page only) |
| Sidebar drawer | 260px, slides in from left with backdrop overlay |
| Nav links | 4 links with emoji prefixes: 📋 Menu, 🧾 Orders, ⚙️ Options, 👥 Users |
| Active state | Pink left border + soft pink background, detected via `window.location.pathname` |
| Footer | User info + Sign Out button |
| Body offset | `padding-top: 52px` applied to all 4 pages to clear fixed topbar |

Files affected: `admin/index.html`, `admin/orders.html`, `admin/options.html`, `admin/users.html`

---

## Task 8 — Global Cross-Cutting

| # | Improvement | Files |
|---|---|---|
| 1 | **Shared CSS file** — `/css/design-system.css` created; `:root` block defined once; all 7 files link to it | `/css/design-system.css`, all 7 HTML files |
| 2 | **Typography tokens** — `--text-xs` through `--text-3xl` added to design system; applied across all `<style>` blocks | `/css/design-system.css` |
| 3 | **Shimmer skeleton loading** — `@keyframes shimmer` + `.skeleton-*` classes added globally; all 4 admin pages show animated placeholders instead of "Loading…" text | `/css/design-system.css`, all 4 admin pages |
| 4 | **iOS safe area fix** — all 7 files updated with `viewport-fit=cover`; toast `bottom` uses `calc(Xpx + env(safe-area-inset-bottom, 0px))` | All 7 HTML files |
| 5 | **Error banners** — dismissable red error banner with Retry button on all 4 admin pages, wired to Supabase error catch blocks | All 4 admin pages |
| 6 | **Animated modals** — `opacity + visibility + pointer-events` pattern replaces `display:none/flex`; modal box gets scale + translateY animation | `admin/index.html`, `admin/options.html`, `admin/users.html` |
| 7 | **Spacing tokens** — `--space-1` through `--space-10` added to design system, applied to layout-level containers | `/css/design-system.css` |
| 8 | **Dynamic order queue tab title** — browser tab shows `(3) Order Queue` when new orders are pending | `admin/orders.html` |

---

## Task 9 — Bug Fixes

| # | Bug | Cause | Fix |
|---|---|---|---|
| 1 | Action dropdown clipping (`admin/index.html`) | `.action-dropdown` used `position: absolute`, clipped by parent overflow contexts | Changed to `position: fixed`; `toggleActionMenu()` now uses `getBoundingClientRect()` for viewport-relative positioning; opens upward when near bottom of page; scroll/resize listeners close any open dropdown |
| 2 | Users page load error (`admin/users.html`) | `email` column included in Supabase `.select()` string, but `user_profiles` has no email column — auth emails live in Supabase's internal `auth.users` | Removed `email` from `.select()`; email cell correctly shows `—` as fallback |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `login.html` | Brand alignment, animated panel switch, show/hide toggle, divider, layout |
| `reset-password.html` | Brand alignment, hint text, back link, show/hide toggle, divider, layout |
| `admin/index.html` | Full UI overhaul — action dropdown, summary bar, image preview, drag handle, sidebar, bug fix |
| `admin/orders.html` | Full UI overhaul — color headers, age badges, item row split, search bar, sidebar, tab title |
| `admin/options.html` | Full UI overhaul — input labels, drag reorder, keyboard accessibility, delete modal, sidebar |
| `admin/users.html` | Full UI overhaul — CSS classes, email column, confirmation dialog, badge, current user row, sidebar, bug fix |
| `css/design-system.css` | New file — shared `:root` variables, typography tokens, spacing tokens, shimmer skeleton |

---

---

# Phase 1B — KDS Integration, Bug Fixes & Printer Foundation
**Session Date:** 2026-05-30
**Scope:** Order queue KDS merge, Realtime race condition fix, FK constraint fix, receipt engine, printer management page

---

## Phase 1B Deliverables (Completed)

| # | Deliverable | Files |
|---|---|---|
| 1 | KDS merged into Order Queue — 3-section card, all roles, live timer, audio ping | `admin/orders.html` |
| 2 | Realtime race condition fix — debounced reload + `order_item_options` subscription | `admin/orders.html` |
| 3 | FK constraint fixed — `choice_id` now references `option_template_choices` | Supabase SQL (manual) |
| 4 | Receipt engine — 58mm thermal format, shared across all pages | `js/receipt.js` |
| 5 | Printer management page — add/edit/delete/status/test print | `admin/printer.html` |
| 6 | Printer nav link added to all admin sidebars | All 4 admin pages |

---

## Task 1 — KDS + Order Queue Merge (`admin/orders.html`)

Integrated KDS functionality directly into the existing order queue page instead of creating a separate `kitchen/index.html`. All roles (`admin`, `manager`, `cashier`, `kitchen`, `staff`) are now authorized.

### Card Redesign — 3 Sections

| Section | Content |
|---|---|
| **TOP** | Order #, order type badge (with table no), age badge (green/amber/red), customer name + phone, delivery address |
| **MIDDLE** | Pink-soft background. Items with qty + name + options (colored left border per column status). Per-item notes italic. Order-level note in amber block. |
| **BOTTOM** | Surface-warm background. Total price, payment toggle (Unpaid → Paid), kitchen status button (▶ Prepare / ✓ Ready / Served), cancel ✕, live ⏱ timer |

### KDS Features Added

| Feature | Implementation |
|---|---|
| Live timer | `data-timer-start` on each card span; `setInterval` every 1s updates text only — no DOM rebuild |
| Timer colors | Green < 5 min, amber 5–10 min, red > 10 min |
| Audio ping | Web Audio API two-note tone on `orders` INSERT Realtime event; AudioContext primed on first user click |
| Column item borders | CSS `[data-status]` attribute — amber (New), pink (Preparing), green (Ready) |
| All roles authorized | `Auth.require(['admin','manager','cashier','kitchen','staff'])` |

---

## Task 2 — Realtime Race Condition Fix (`admin/orders.html`)

### Problem
When a customer submitted an order, the order card appeared with no items or options. Refresh fixed it.

### Root Cause
`index.html` inserts in 3 sequential steps: `orders` → `order_items` → `order_item_options`. The Realtime INSERT on `orders` triggered `loadOrders()` immediately — before `order_items` and `order_item_options` existed in the database.

### Fix

```js
// Debounced reload — fires once after all inserts settle
let reloadTimer = null;
function scheduleReload(ms = 0) {
  clearTimeout(reloadTimer);
  reloadTimer = setTimeout(loadOrders, ms);
}
```

| Event | Behaviour |
|---|---|
| `orders` INSERT | Play ping + schedule reload in **3000ms** (fallback) |
| `order_item_options` INSERT | Reset timer to **500ms** — fires after last option lands |
| `orders` UPDATE | Reload **immediately** |

**SQL required (Supabase SQL Editor):**
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE order_item_options;
```

---

## Task 3 — FK Constraint Fix (Supabase SQL)

### Problem
Submitting an order threw: `insert or update on table "order_item_options" violates foreign key constraint "order_item_options_choice_id_fkey"`

### Root Cause
Migration 003 moved option choices from `option_choices` to `option_template_choices`. The FK constraint on `order_item_options.choice_id` still pointed to the old `option_choices` table.

### Fix (run in Supabase SQL Editor)

```sql
-- Drop FK (regardless of current state)
ALTER TABLE order_item_options
  DROP CONSTRAINT IF EXISTS order_item_options_choice_id_fkey;

-- Nullify stale choice_ids from old test orders
UPDATE order_item_options
SET choice_id = NULL
WHERE choice_id IS NOT NULL
  AND choice_id NOT IN (SELECT id FROM option_template_choices);

-- Add correct FK
ALTER TABLE order_item_options
  ADD CONSTRAINT order_item_options_choice_id_fkey
  FOREIGN KEY (choice_id)
  REFERENCES option_template_choices(id)
  ON DELETE SET NULL;
```

`ON DELETE SET NULL` preserves order history when a template choice is later deleted — `choice_name` and `additional_price` snapshots keep display data intact.

---

## Task 4 — Receipt Engine (`js/receipt.js`)

Shared receipt builder for 58mm thermal paper (XPrinter XP-58IIL and compatible).

### Functions

| Function | Description |
|---|---|
| `buildReceiptHTML(order, shopConfig)` | Returns full receipt HTML string — 58mm `@page`, Courier New, monospace table layout |
| `printOrderReceipt(order, shopConfig)` | Opens popup window and triggers `window.print()` |
| `testPrintReceipt(shopConfig)` | Prints a pre-built dummy order for format testing |
| `RECEIPT_TEST_ORDER` | Exported test data constant |

### Receipt Format (58mm)

```
🍵 GLONGNOM MATCHA 🍵
มัทฉะคราฟท์สดใหม่
Tel: 0XX-XXX-XXXX
════════════════════════
30/05/2569  14:30
Order #G-0042 | Delivery
────────────────────────
ชื่อ: Somchai Rakdee
โทร: 089-123-4567
ส่งที่: U Baan อาคาร A
📝 หมายเหตุออเดอร์
────────────────────────
2x Matcha Latte   150.00
  • น้ำตาลน้อย, ไม่มีน้ำแข็ง
1x Green Tea       60.00
  • น้ำตาลปกติ
  📝 Extra hot please
────────────────────────
════════════════════════
รวมทั้งหมด        210.00 ฿
════════════════════════
ขอบคุณที่อุดหนุนนะคะ ♡
กลับมาอีกนะคะ 🌿
@glongnom_matcha
```

---

## Task 5 — Printer Management Page (`admin/printer.html`)

| Feature | Detail |
|---|---|
| **Add printer** | Name, model, connection type (Browser / Network), IP, port, notes, set as default |
| **Edit printer** | Pre-filled modal |
| **Delete printer** | Confirmation modal |
| **Status check** | `fetch(http://ip/, {mode:'no-cors'})` with 3s timeout — detects online/offline without agent |
| **Receipt preview** | In-page preview panel showing sample receipt in Courier New |
| **Test print** | Calls `testPrintReceipt()` from `receipt.js` — opens 58mm popup |
| **Set default** | Marks one printer as default, clears others |
| **Auth** | admin + manager only |

### Supabase Table Required

```sql
CREATE TABLE IF NOT EXISTS public.printers (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name            text NOT NULL,
  model           text DEFAULT 'XPrinter XP-58IIL',
  connection_type text DEFAULT 'browser' CHECK (connection_type IN ('browser','network')),
  ip_address      text,
  port            integer DEFAULT 9100,
  is_default      boolean DEFAULT false,
  notes           text,
  last_status     text DEFAULT 'unknown',
  last_checked_at timestamptz,
  created_at      timestamptz DEFAULT now()
);
ALTER TABLE public.printers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "printers_read"  ON public.printers FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "printers_write" ON public.printers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin','manager'))
);
```

---

## Remaining Printer Tasks (Future)

- Add **Print Receipt** button to each order card in `admin/orders.html`
- Connect shop config (name, phone) live from Supabase `shops` table into receipt
- **ESC/POS local print agent** — Node.js bridge from browser → TCP 9100 → printer (when needed)
- Multi-station routing — kitchen slip vs cashier receipt

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `admin/orders.html` | Full KDS integration — 3-section card, timer, audio ping, debounced Realtime, all roles |
| `admin/printer.html` | New file — printer management page |
| `js/receipt.js` | New file — shared 58mm receipt engine |
| `admin/index.html` | Sidebar: added Printers link |
| `admin/options.html` | Sidebar: added Printers link |
| `admin/users.html` | Sidebar: added Printers link |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort | admin, manager |
| `/admin/orders.html` | Live order queue + KDS | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/login.html` | Staff login + forgot password | — |
| `/reset-password.html` | Set/reset password from email link | — |

---

---

# Phase 2 — Inventory & Costing System
**Session Date:** 2026-05-30
**Scope:** Full Phase 2 build — BOM engine, inventory management, cost tracking, supplier + PO management, auto-print receipt, bug fixes

---

## Phase 2 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — 7 new tables, indexes, RLS, stored functions | `supabase/migrations/004_phase2_inventory.sql` |
| 2 | Migration amendments — `partial` status + `receive_po_items` function | `supabase/migrations/005_phase2_amendments.sql` |
| 3 | Inventory management page — ingredients CRUD, stock adjust, wastage log | `admin/inventory.html` |
| 4 | BOM builder — assign ingredients + quantities per menu item | `admin/inventory.html` (Tab 2) |
| 5 | BOM deduction engine — auto-deduct stock on order `served` | `admin/orders.html`, Supabase RPC `deduct_bom_for_order` |
| 6 | Food cost columns on menu page — Cost ฿ + FC% with color coding | `admin/index.html` |
| 7 | Supplier management page — CRUD, active/inactive | `admin/suppliers.html` |
| 8 | Purchase order management page — create, submit, receive, cancel | `admin/purchase-orders.html` |
| 9 | Auto-print receipt on new order — OFF by default, toggle in topbar | `admin/orders.html`, `js/receipt.js` |
| 10 | Sidebar nav updated across all admin pages — Inventory, Suppliers, Purchases links | All 8 admin pages |

---

## Schema Design (Holmes Review — 2026-05-30)

### New Tables

| Table | Purpose |
|---|---|
| `ingredients` | Ingredient catalog with stock, reorder level, cost per unit |
| `recipe_bom` | Bill of Materials — ingredient quantities per menu item |
| `inventory_adjustments` | Audit log for all manual stock changes and wastage |
| `inventory_deductions` | Idempotency log for BOM deduction engine |
| `suppliers` | Supplier profiles |
| `purchase_orders` | PO headers (draft → submitted → partial → received → cancelled) |
| `purchase_order_items` | PO line items with quantity ordered/received and unit cost |

### Stored Functions

| Function | Purpose |
|---|---|
| `deduct_bom_for_order(order_id)` | Atomic BOM deduction on order served — single transaction, idempotent |
| `adjust_ingredient_stock(id, delta)` | Safe stock adjustment (floors at 0) |
| `receive_po_items(po_id, receipts)` | Atomic goods receipt — updates stock, weighted average cost, audit log, PO status |

### Key Design Decisions

| Decision | Choice |
|---|---|
| Unit handling | Single canonical unit per ingredient — CHECK constraint enforced |
| Deduction trigger | `status = 'served'` |
| Soft delete | `is_active = false` on ingredients — no hard deletes |
| Atomicity | Postgres stored functions via `supabase.rpc()` |
| Cost update on receipt | Weighted average cost |
| PO partial deliveries | PO stays open, receives in batches, auto-transitions to `partial` / `received` |

---

## Food Cost Formulas (Finn Validation — 2026-05-30)

| Formula | Definition |
|---|---|
| Recipe Cost | Σ (quantity_used × cost_per_unit) across all BOM entries |
| Food Cost % | Recipe Cost / base_price × 100 |
| Gross Margin % | (base_price − Recipe Cost) / base_price × 100 |
| Suggested Price | ROUND_UP_TO_5(Recipe Cost / 0.30) |

- **Target food cost %: 30%** (Thai beverage cafe benchmark)
- FC% color coding: green ≤ 30%, amber 31–35%, red > 35%
- Tooltip: "Ingredient cost only. Does not include labor or overhead."

---

## Auto-Print Receipt

- Triggers automatically on Supabase Realtime `orders` INSERT event
- Calls `printOrderReceipt(order, shopConfig)` from `js/receipt.js`
- Only fires for new orders (INSERT), not status updates
- **Default: OFF** — toggle in topbar: `🖨 Auto-print: OFF/ON`
- State persisted in `localStorage` key `glongnom_autoprint`
- Shop config loaded once on init from `shops` table

---

## Bugs Fixed This Session

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | Add ingredient shows success but never appears in table | Two `async function saveIngredient` in same script — second override caused infinite self-recursion; Supabase insert never ran | Renamed internal writer to `_writeIngredient(data)` |
| 2 | Purchase orders page shows "Failed to load" on every open | `submitted_at` column doesn't exist in `purchase_orders` table — all SELECT/INSERT/UPDATE referencing it caused Supabase to error | Removed all 4 `submitted_at` references from the page |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `000_reset.sql` | Drop all tables |
| `001_initial_schema.sql` | Core tables, RLS, Realtime |
| `002_seed_menu.sql` | 22 menu items + option groups |
| `003_option_templates.sql` | Option Template System |
| `004_phase2_inventory.sql` | Phase 2 — all 7 inventory tables + functions |
| `005_phase2_amendments.sql` | Add `partial` status + `receive_po_items` function |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort + FC% columns | admin, manager |
| `/admin/orders.html` | Live order queue + KDS + auto-print toggle | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/admin/inventory.html` | Ingredient CRUD + BOM builder | admin, manager |
| `/admin/suppliers.html` | Supplier management | admin, manager |
| `/admin/purchase-orders.html` | Purchase order lifecycle | admin, manager |

---

## Local Development

Run locally with no Netlify deploy needed:

```bash
npx serve .
# Opens at http://localhost:3000
# Clean URLs — use /admin/inventory not /admin/inventory.html
```

Netlify Functions (LINE notify, invite-user) require `netlify dev` instead.

---

## Next Phase

**Phase 3 — Operations & Business Intelligence** ✅ Complete (see below)

---

---

# Phase 3 — Operations & Business Intelligence
**Session Date:** 2026-05-31
**Scope:** Dashboard migration (Google Sheets → Supabase), CRM + Loyalty System, Interactive Reports page, Bug fixes

---

## Phase 3 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Dashboard migrated — Google Apps Script removed, all data from Supabase | `admin/dashboard.html` |
| 2 | CRM schema — loyalty_points, tier, birthday on customers + loyalty_ledger table | `supabase/migrations/006_phase3_crm.sql` |
| 3 | CRM page — customer list, order history, loyalty points, tier progression | `admin/customers.html` |
| 4 | Loyalty accrual hook — auto-accrues points on order served | `admin/orders.html` |
| 5 | Reports page — 3-tab interactive tables (Sales, Menu & Options, Inventory) | `admin/reports.html` |
| 6 | RLS fix — customers table SELECT policy for authenticated users | `supabase/migrations/007_rls_fixes.sql` |
| 7 | Sidebar nav updated across all admin pages — Dashboard, Reports, Customers links | All admin pages |

---

## Task 1 — Dashboard (`admin/dashboard.html`)

Migrated from Google Apps Script to Supabase. React UI kept intact — only the data layer replaced.

| Card | Supabase Source |
|---|---|
| Revenue / Orders / Avg Basket / Customers KPIs | `orders` table, aggregated in JS |
| Revenue chart (hourly/daily) | `orders` grouped by hour or date |
| Top sellers | `order_items` JOIN `menus` JOIN `categories` |
| Options analysis | `order_item_options` via `order_items` for current period orders |
| Heatmap (day × hour) | `orders` grouped by DOW × hour |
| Top customers | `customer_name` from orders (direct column, works for all historical data) |
| Live feed | Latest 10 `orders` with Realtime subscription |
| Today hourly | `orders` for today, bucketed into 13 hourly slots (08:00–20:00) |

**Auth guard added:** admin + manager only. Sidebar added matching all other admin pages.

---

## Task 2 — CRM System (`admin/customers.html`)

### New Schema (migration `006_phase3_crm.sql`)

| Table / Column | Purpose |
|---|---|
| `customers.loyalty_points` | Running point total (integer, default 0) |
| `customers.tier` | bronze / silver / gold (auto-updated by RPC) |
| `customers.birthday` | date (optional) |
| `customers.notes` | freetext notes |
| `loyalty_ledger` | Full transaction history — delta, reason, order_id, created_at |

### Stored Functions

| Function | Purpose |
|---|---|
| `accrue_loyalty_for_order(p_order_id)` | Idempotent — floor(total/10) pts earned, updates tier |
| `adjust_loyalty_points(p_customer_id, p_delta, p_reason, p_note)` | Manual adjustment, floors at 0, updates tier |

### Tier Thresholds (Finn-validated)

| Tier | Points | Visits to reach (฿100 avg, 2×/week) |
|---|---|---|
| Bronze | 0 – 299 pts | Immediate |
| Silver | 300 – 999 pts | ~30 visits / 3.5 months |
| Gold | 1,000+ pts | ~100 visits / 12 months |

### Page Features
- Left panel: customer list sorted by points (desc), real-time name/phone search
- Right panel: editable profile, 4-stat bar, tier + progress bar, manual point adjustment (admin/manager only), order history timeline, loyalty ledger table
- Deep-link: `/admin/customers.html?id=UUID` auto-opens customer detail
- Orders page: "View →" link on each order card routes to customer detail

---

## Task 3 — Reports Page (`admin/reports.html`)

Three fully interactive tabs — all data from Supabase.

### Tab 1 — Sales
- Filters: period, order type, payment status, order # search
- 10-column sortable table with paginated results (50 rows/page)
- Summary: total orders + total revenue (incl. delivery) + cancelled count
- CSV export fetches all matching rows (not just current page), UTF-8 BOM for Excel

### Tab 2 — Menu & Options
- Filters: period, category dropdown, menu name search
- Columns: Rank, Menu, Category, Qty Sold, Revenue, Avg Price, Recipe Cost, FC%, Top Choice
- FC% color: green ≤30%, amber 31–35%, red >35%, dash if no BOM
- BOM cost + top option fetched in parallel via `Promise.all()`

### Tab 3 — Inventory
- Filters: period (affects deducted/restocked/wastage totals), status filter (All/Low/Critical), name search
- Columns: Ingredient, Unit, Current Stock, Reorder Level, Status, Deducted, Restocked, Wastage, Cost/Unit, Stock Value
- Summary: total stock value + deducted + wastage + alert counts

**Default period:** Week (changed from Today — avoids empty table on first load)

---

## Bugs Fixed This Session

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | `customer_id: null` on every order | `index.html` hardcoded `customer_id: null` — upserted customer but never retrieved the UUID | Chained `.select('id').single()` on upsert; passes `customerId` to order insert |
| 2 | Top customers empty on dashboard | All orders had `customer_id = null` (Bug 1) | Dashboard now reads `customer_name` directly from orders — works for all historical data |
| 3 | Customers page shows 0 orders | `orders()` nested select had no FK hint — Supabase couldn't traverse reverse relation | Changed to `orders!customer_id(...)` |
| 4 | Inventory tab error loading | `inventory_deductions` uses `deducted_at` not `created_at`; `inventory_adjustments` type column is `adjustment_type` not `reason` | Corrected both column names in query and reduce logic |
| 5 | Menu tab revenue mismatch vs Sales | `orders!order_id` (LEFT JOIN) meant cancelled-order filter applied only to embedded object, leaking cancelled items into Menu revenue | Restored `orders!inner` — inner join correctly filters outer rows |
| 6 | Search by order # broken | `.or()` with `customers.name.ilike` on foreign table not supported by Supabase PostgREST | Replaced with direct `.ilike('order_no', ...)` on main table |
| 7 | Options analysis empty on dashboard | `order_item_options` has no `created_at` column — date filter errored silently | Rewired to filter via `currOrderIds → order_items → order_item_options` |
| 8 | Category mix all same color on dashboard | `CAT_COLORS` mapped hardcoded English keys; real DB category names don't match | Replaced with `CAT_PALETTE` — 8-color array assigned by sorted index |
| 9 | Today's orders not showing | Menu tab `orders!order_id` (LEFT JOIN) not enforcing status filter on outer rows | Restored `orders!inner`; revenue now matches between tabs |

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `006_phase3_crm.sql` | CRM tables — loyalty_points, tier, birthday, loyalty_ledger + 2 stored functions |
| `007_rls_fixes.sql` | customers table SELECT policy for authenticated users |

---

## Admin Panel Pages (Updated)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/dashboard.html` | Live sales dashboard — KPIs, charts, heatmap, top sellers | admin, manager |
| `/admin/customers.html` | CRM — customer list, order history, loyalty points, tier | admin, manager, cashier |
| `/admin/reports.html` | Interactive reports — Sales, Menu & Options, Inventory tabs | admin, manager |

---

---

# Phase 4 — Accounting & Finance
**Session Date:** 2026-05-31
**Scope:** Accounting journal page, Finance P&L page (contribution format), auto-recording hooks, fixed costs management

---

## Phase 4 Deliverables (All Complete)

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — accounting_entries, fixed_costs tables + 2 stored functions | `supabase/migrations/008_phase4_accounting.sql` |
| 2 | Accounting page — journal entries, auto + manual, balance summary | `admin/accounting.html` |
| 3 | Finance page — P&L contribution format + fixed costs manager | `admin/finance.html` |
| 4 | Auto-record income hook — fires on order marked Paid | `admin/orders.html` |
| 5 | Auto-record expense hook — fires on PO received | `admin/purchase-orders.html` |
| 6 | Sidebar nav updated — Accounting + Finance links | All 11 admin pages |

---

## Schema Design (migration `008_phase4_accounting.sql`)

### New Tables

| Table | Purpose |
|---|---|
| `accounting_entries` | Journal entry log — income and expense records with auto/manual flag |
| `fixed_costs` | Fixed cost definitions — rent, salary, utilities, etc. with period type and effective dates |

### `accounting_entries` Key Columns

| Column | Notes |
|---|---|
| `entry_type` | `income` or `expense` |
| `category` | `sales`, `purchase`, `labor`, `rent`, `utilities`, `other` |
| `reference_type` | `order`, `purchase_order`, `manual` |
| `is_auto` | `true` = system-generated, cannot be deleted by user |

### `fixed_costs` Key Columns

| Column | Notes |
|---|---|
| `period_type` | `monthly`, `weekly`, `yearly` — used for P&L proration |
| `effective_from` / `effective_to` | Date range when cost is active; `effective_to = NULL` means ongoing |

### Stored Functions

| Function | Purpose |
|---|---|
| `record_order_income(p_order_id)` | Idempotent — records income entry when order is paid |
| `record_purchase_expense(p_po_id)` | Idempotent — sums `quantity_ordered × unit_cost` from PO items, records expense |

---

## Task 1 — Accounting Page (`admin/accounting.html`)

- Period picker (default: Month)
- **Summary bar:** Total Income (green) | Total Expense (red) | Net Balance (green if +, red if −)
- Transaction table: Date, Description (🔒 if auto), Type badge, Category badge, +/− Amount, Actions
- Auto-generated entries (orders paid, POs received) are read-only — delete blocked with toast
- Add/Edit modal for manual entries: date, description, type, category, amount
- Client-side filters: type dropdown, category dropdown, text search
- CSV export respects current filters and sort

---

## Task 2 — Finance Page (`admin/finance.html`)

- Period picker (default: Month; minimum 7 days enforced)
- Two-panel layout: P&L Statement (left, 60%) | Fixed Costs Manager (right, 40%)

### P&L Statement — Contribution Format

```
REVENUE
  Sales Revenue              ฿ X,XXX.XX    (accounting_entries income/sales in period)

VARIABLE COSTS (COGS)
  Cost of Goods Sold         ฿ X,XXX.XX    (inventory_deductions × ingredients.cost_per_unit)

CONTRIBUTION MARGIN          ฿ X,XXX.XX    (Revenue − COGS)
  Contribution Margin %      XX.X%

FIXED COSTS
  [each fixed cost name]     ฿ X,XXX.XX    (prorated for selected period)
  Total Fixed Costs          ฿ X,XXX.XX

NET INCOME                   ฿ X,XXX.XX    (green = profit, red = loss)
  Net Margin %               XX.X%
```

**COGS calculation:**
1. Fetch served orders in period
2. Fetch `inventory_deductions` for those orders joined with `ingredients(cost_per_unit)`
3. COGS = Σ (quantity_deducted × cost_per_unit)

**Fixed cost proration:**
- Monthly cost prorated as: `amount × (period_days / 30)`
- Weekly: `amount × (period_days / 7)`
- Yearly: `amount × (period_days / 365)`

### Fixed Costs Manager (right panel)

- List all active fixed costs with Edit/Delete buttons
- Add Fixed Cost modal: name, amount, period type, effective from/to, active toggle
- Any change auto-refreshes the P&L statement

---

## Auto-Recording Hooks

| Trigger | Function Called | Location |
|---|---|---|
| Order marked **Paid** | `record_order_income(orderId)` | `admin/orders.html` → `markPaid()` |
| PO marked **Received** | `record_purchase_expense(poId)` | `admin/purchase-orders.html` → `confirmReceive()` |

Both hooks are fire-and-forget (`.catch(console.warn)`) — a recording failure never blocks the main operation.

---

## Database Migrations (Run Order)

| File | Purpose |
|---|---|
| `008_phase4_accounting.sql` | accounting_entries + fixed_costs tables + 2 stored functions |

---

## Admin Panel Pages (Final State)

| URL | Purpose | Role Required |
|---|---|---|
| `/admin/` | Menu management + drag sort + FC% columns | admin, manager |
| `/admin/orders.html` | Live order queue + KDS + auto-print + shop toggle | all roles |
| `/admin/options.html` | Option template CRUD + assign | admin, manager |
| `/admin/users.html` | Staff management + invite | admin, manager |
| `/admin/printer.html` | Printer config + test print | admin, manager |
| `/admin/inventory.html` | Ingredient CRUD + BOM builder + compound ingredients | admin, manager |
| `/admin/suppliers.html` | Supplier management | admin, manager |
| `/admin/purchase-orders.html` | Purchase order lifecycle + big-unit input | admin, manager |
| `/admin/dashboard.html` | Live sales dashboard | admin, manager |
| `/admin/customers.html` | CRM — loyalty, order history | admin, manager, cashier |
| `/admin/reports.html` | Interactive reports — 3 tabs | admin, manager |
| `/admin/accounting.html` | Journal entries + PO# search | admin, manager |
| `/admin/finance.html` | P&L statement (white) + fixed costs | admin, manager |

---

---

# Bug Fixes & Feature Improvements — Session 5
**Session Date:** 2026-06-01
**Scope:** Bug fixes across all admin pages, inventory big-unit system, compound ingredients, purchase order unit alignment, accounting grants & backfill, period picker standardisation, sidebar navigation restructure

---

## Task 1 — Dashboard Improvements (`admin/dashboard.html`)

| # | Change | Detail |
|---|---|---|
| 1 | Removed Options Analysis card | Decluttered dashboard — moved to Reports page |
| 2 | Top Customers — added Total Spent column | Sorted by total spending (more meaningful than order count) |
| 3 | Layout re-balanced | Top Sellers `col-7` + Category Mix `col-5` (was `col-5` + `col-4` + `col-3`) |

---

## Task 2 — Menu Management Bug Fix (`admin/index.html`)

| # | Bug | Fix |
|---|---|---|
| 1 | `•••` button wrapping to new row | Changed `.actions` from `flex-wrap: wrap` → `flex-wrap: nowrap; white-space: nowrap` |

---

## Task 3 — Loyalty Points Fix (`admin/customers.html`, `admin/orders.html`)

**Root cause chain:**
1. No `UPDATE` RLS policy on `customers` table → upsert's `ON CONFLICT phone DO UPDATE` was blocked for returning customers → `customer_id = null` on orders
2. `accrue_loyalty_for_order` early-returns when `customer_id IS NULL` → no points
3. Fire-and-forget `.catch()` in `orders.html` swallowed Supabase errors silently

| # | Fix | File |
|---|---|---|
| 1 | Migration 009 — `customers_update` RLS policy, `recalculate_loyalty_for_customer` RPC | `009_crm_rls_fix.sql` |
| 2 | "↺ Recalculate from Orders" button — backfills points for existing customers | `admin/customers.html` |
| 3 | Loyalty accrual changed from fire-and-forget to `await` | `admin/orders.html` |

---

## Task 4 — Inventory Big-Unit / Small-Unit System (`admin/inventory.html`)

Complete redesign of ingredient input to separate purchase units (big) from usage units (small).

### New 8-Step Ingredient Form

| Step | Field | Logic |
|---|---|---|
| 1 | Name | Text input |
| 2 | Type | วัตถุดิบ / บรรจุภัณฑ์ |
| 3 | Big unit | kg / L / ขวด / กล่อง / กระปุก / ถุง / แพค / แกลลอน |
| 4 | ราคา / big unit (฿) | User input |
| 5 | Conversion | 1 big unit = N small units (g / ml / pcs) |
| 6 | ฿ / small unit | Auto-calculated = field 4 ÷ field 5 |
| 7 | Current stock (big units) | Input → auto-converts to small units for storage |
| 8 | Reorder level (big units) | Input → auto-converts to small units for storage |

### Storage Strategy
- `unit` = small unit (g/ml/pcs) — canonical DB storage and BOM usage unit
- `big_unit` = purchase unit label
- `units_per_big` = conversion ratio
- `cost_per_big` = purchase price stored directly (avoids reverse-calculation precision loss)
- `cost_per_unit` = `cost_per_big / units_per_big` — derived, stored with full numeric precision

### Table Display
- Primary: big-unit stock + big-unit cost (what the owner thinks in)
- Secondary muted: small-unit stock + small-unit cost (what BOM uses)
- Adjust stock / Wastage modals: input in big units, convert internally

### Migrations

| File | Purpose |
|---|---|
| `010_ingredient_units.sql` | `ingredient_type`, `big_unit`, `units_per_big`, `cost_per_big` columns |
| `011_compound_ingredients.sql` | `is_compound`, `batch_yield`, `compound_ingredient_parts` table; updated `deduct_bom_for_order` |

### Cost Display Fix
- `cost_per_unit numeric(10,2)` was the root cause of "0.0000 THB/ml" bug — `0.075` stored as `0.08`
- Migration 011 runs `ALTER COLUMN cost_per_unit TYPE numeric` (removes scale constraint)
- `fmtCost4()` — adaptive decimal formatter: shows enough dp to represent the actual value (e.g. `฿0.000150` not `฿0.0000`)

---

## Task 5 — Compound Ingredients (`admin/inventory.html`)

New concept: ingredients made from other ingredients (e.g. น้ำเชื่อม, น้ำปรุง).

| Feature | Detail |
|---|---|
| Modal toggle | "วัตถุดิบผสม" checkbox; hides cost field, shows recipe builder |
| Batch yield | How much compound ingredient the recipe produces (in big units) |
| Parts builder | Select raw ingredient + qty (in small units); live cost per line |
| Auto-cost calc | Total cost / batch → ฿/big unit → ฿/small unit |
| Table badge | Amber "ผสม" badge on compound ingredient rows |
| Chain deduction | `deduct_bom_for_order` resolves compound BOM entries → deducts raw parts, not the compound; `ON CONFLICT DO UPDATE` aggregates when same raw ingredient appears in multiple compound BOMs |

---

## Task 6 — BOM Seed (`supabase/migrations/012_bom_seed_common.sql`)

Added 8 common base ingredients + BOM entries for all 19 active Matcha & Drinks menus.

| Ingredient | Unit | Type |
|---|---|---|
| น้ำเชื่อมมิตรผล | ml | ingredient |
| น้ำแข็ง | g | ingredient |
| แก้ว PET 14oz + ฝายกดื่มปาก 98 | pcs | packaging |
| กระดาษปิดกันน้ำ | pcs | packaging |
| ถ้วยพลาสติก 3 oz | pcs | packaging |
| ถุงซิปน้ำแข็ง 12*17 | pcs | packaging |
| ถุงหิ้วเดี่ยวไฮโซ | pcs | packaging |
| หลอดไม่งอ 6 มิล | pcs | packaging |

---

## Task 7 — Purchase Orders Big-Unit Alignment (`admin/purchase-orders.html`)

**Root cause:** `receive_po_items` adds `qty_received` directly to `current_stock` (small units) and uses `unit_cost` as cost per small unit. The old UI stored big-unit values, causing a unit mismatch.

| Change | Detail |
|---|---|
| `loadIngredients` | Now fetches `big_unit`, `units_per_big`, `cost_per_big`, `cost_per_unit` |
| PO builder | Dropdown stores big-unit metadata; unit cost auto-fills from `cost_per_big`; all inputs in big units |
| Save logic | Converts big → small before inserting (`qty × upb`, `cost / upb`) |
| Detail view | Converts small → big for display |
| Receive modal | Input in big units; converts before RPC; `data-upb` on each row |
| `confirmReceive` | Proper try-catch, close modal + toast immediately on success (not after `loadPOs`), removed flawed JS over-receipt guard (DB handles it) |
| Migration 013 | `unit_cost TYPE numeric` (was `numeric(10,2)`); `receive_po_items` ROUND `2` → `6` dp |
| PO# search | Search box in list view; searches by PO#, supplier name, status |

---

## Task 8 — Accounting & Finance Bug Fixes

### Root Cause: Missing GRANT EXECUTE (Migration 014)

`record_order_income` and `record_purchase_expense` were created in migration 008 **without** `GRANT EXECUTE TO authenticated`. Every call from the frontend returned "permission denied" — silently swallowed by `.catch()`.

| Migration | Fix |
|---|---|
| `014_accounting_grants.sql` | `GRANT EXECUTE` for both functions; `SET search_path = public`; `record_purchase_expense` now uses `quantity_received × unit_cost` (not `quantity_ordered`) |
| `015_accounting_backfill.sql` | Backfills all historical paid orders and received POs; uses Bangkok timezone for `entry_date` |
| `016_accounting_timezone.sql` | Replaces `CURRENT_DATE` with `(NOW() AT TIME ZONE 'Asia/Bangkok')::date` in both functions; uppercases PO# in descriptions |

### Hooks Fixed
| File | Change |
|---|---|
| `admin/orders.html` — `markPaid()` | Changed from fire-and-forget `.catch()` → `await` with error logging |
| `admin/purchase-orders.html` — `confirmReceive()` | Same fire-and-forget → `await` fix |

---

## Task 9 — Period Picker Standardisation (All Pages)

Replaced inconsistent period labels (Today/Week/Month) with rolling-window labels across all 4 data pages.

| Page | Old | New |
|---|---|---|
| `dashboard.html` | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `reports.html` (all 3 tabs) | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `accounting.html` | Today / Week / Month / Custom | Today / Last 7d / Last 30d / Custom |
| `finance.html` | Week / Month / Custom | Today / Last 7d / Last 30d / Custom |

Additional:
- Removed 7-day minimum for finance custom range (Today is now valid)
- Default period changed from `month` → `30d` on accounting and finance

### Accounting PO# Search
- Search bar added to accounting.html — searches `description` AND `reference_id` (hyphens stripped for flexible UUID matching)

---

## Task 10 — Finance P&L White Background (`admin/finance.html`)

Added `style="background:#ffffff;"` inline on the P&L Statement card only. Fixed Costs Manager card keeps the warm cream background.

---

## Task 11 — Sidebar Navigation Restructure (All 13 Admin Pages)

Replaced flat 13-link list with 4 labelled groups.

| Group | Pages |
|---|---|
| **Management** | Order Queue, Menu Management, Options, Customers |
| **Inventory** | Inventory, Suppliers, Purchases |
| **Analysis** | Dashboard, Reports, Accounting, Finance |
| **Setting** | Staff, Printers |

**CSS added to `design-system.css`:**
- `.sidebar-group-label` — section header style (10px, uppercase, muted)
- `.sidebar-nav { flex: 1; overflow-y: auto; min-height: 0; }` — scroll fix for long nav lists

---

## Task 12 — Shop Open/Close Toggle Moved (`admin/index.html` → `admin/orders.html`)

Toggle relocated from Menu Management topbar to Order Queue topbar — more logical since staff opens the order queue first every shift.

| Change | Detail |
|---|---|
| `admin/index.html` | Removed CSS, button HTML, Close Shop modal, toggle JS functions; `loadShop()` kept (still needs `shopId` for menu item creation) |
| `admin/orders.html` | Added CSS, button between spacer and auto-print toggle, Close Shop modal HTML, full JS (state vars, `loadShop`, `updateShopToggleBtn`, click handler, `closeCloseShopModal`, `confirmCloseShop`); `init()` now calls `await loadShop()` |
| Bug fix | Added `.modal-overlay` + `.modal-overlay.show` CSS to orders.html (page had no modals before) |
| Bug fix | Removed orphaned `}` `});` brackets left in index.html that caused JS syntax error |
| Button labels | Thai: ยกเลิก / 🔒 ปิดร้าน |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `009_crm_rls_fix.sql` | customers UPDATE policy + recalculate_loyalty_for_customer RPC |
| `010_ingredient_units.sql` | big_unit, units_per_big, cost_per_big, ingredient_type columns |
| `011_compound_ingredients.sql` | is_compound, batch_yield, compound_ingredient_parts; updated deduct_bom_for_order |
| `012_bom_seed_common.sql` | 8 base ingredients + BOM for all Matcha & Drinks menus |
| `013_po_unit_cost_precision.sql` | unit_cost → numeric; receive_po_items ROUND 2→6dp |
| `014_accounting_grants.sql` | GRANT EXECUTE for accounting functions + search_path fix |
| `015_accounting_backfill.sql` | Backfill historical accounting entries with Bangkok timezone dates |
| `016_accounting_timezone.sql` | CURRENT_DATE → Bangkok timezone in both accounting functions |
| `017_bom_option_overrides.sql` | bom_option_overrides table + `_do_ingredient_deduction` helper + updated `deduct_bom_for_order` with option override logic |

---

---

# Option-Based BOM Override System
**Session Date:** 2026-06-02
**Scope:** Allow inventory deduction to be customized per option choice selected by customer

---

## Problem

Base BOM deduction was menu-level only — it ignored which options the customer selected. For example:
- Customer selects **Matcha Grade: High** → system still deducted the default matcha (medium)
- Customer selects **แยกน้ำแข็ง** → system did not deduct the separate ice bag packaging

---

## Solution: `bom_option_overrides` Table + 3 Rule Types

| Action | Description | Example |
|---|---|---|
| `replace` | Swap a default ingredient with another | matcha medium → matcha high |
| `add` | Inject extra ingredients not in base BOM | เลือกแยกน้ำแข็ง → add ถุงซิปน้ำแข็ง |
| `remove` | Skip a default BOM ingredient | เลือกไม่ใส่น้ำแข็ง → skip น้ำแข็ง |

---

## Database Changes

### New Table: `bom_option_overrides`

| Column | Purpose |
|---|---|
| `choice_id` | FK to `option_template_choices` — which option choice triggers this rule |
| `action` | `replace` / `add` / `remove` |
| `target_ingredient_id` | Ingredient to be replaced or removed (required for `replace` / `remove`) |
| `ingredient_id` | Ingredient to use instead or to add (required for `replace` / `add`) |
| `quantity_used` | Qty for `add`; null on `replace` = inherit qty from BOM |

### New Helper Function: `_do_ingredient_deduction(order_id, ingredient_id, total, is_compound, batch_yield)`
Extracted the compound/normal deduction block from `deduct_bom_for_order` into a reusable helper to avoid code duplication.

### Updated: `deduct_bom_for_order`

Per order_item, now runs 3 phases:
1. **Base BOM** — deduct default ingredients, skipping those overridden by chosen options
2. **Replace overrides** — deduct the substitute ingredient (qty from BOM if `quantity_used` is null)
3. **Add overrides** — deduct extra ingredients injected by chosen options

---

## Admin UI Changes (`admin/inventory.html`)

- **BOM Tab** — "⚙ Option Overrides" button appears after selecting a menu
- Clicking opens a modal organized by **Option Group → Choice**
- Each choice shows its current rules (badge + description + delete ✕)
- "+ Rule" button per choice → inline form appears below:
  - Action selector (replace / add / remove)
  - Conditional fields per action type
  - Save / Cancel
- Rules update in-place without full modal reload

---

## Files Changed

| File | Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New migration |
| `admin/inventory.html` | Added ⚙ button, overrides modal, CSS, JS |

---

---

# Promotion Management System
**Session Date:** 2026-06-02
**Scope:** Promotion management in admin/index.html + customer-facing promo logic in index.html

---

## Deliverables

| # | Deliverable | Files |
|---|---|---|
| 1 | Database schema — promotions + promotion_items tables, discount_amount on orders | `supabase/migrations/018_promotions.sql` |
| 2 | Admin promotion management — section tab, promo cards, add/edit/toggle/delete | `admin/index.html` |
| 3 | Customer promo logic — promo loading, effective price, ribbon badges, bundle cart | `index.html` |

---

## Promo Types

| Type | Behavior | Customer View |
|---|---|---|
| `item_discount` | Single/multi menu, % or ฿ off | Red ribbon badge on card, strikethrough original price |
| `bundle` | Set of 2+ menus → fixed bundle_price | Purple "🎁 เซต" tag on all bundled cards, discount line in cart |

---

## Admin UI (`admin/index.html`)

- New page-level tab row: "📋 เมนู" / "🏷 โปรโมชัน"
- On Promotions tab: promo card grid + "+ เพิ่มโปรโมชัน" button
- Each card shows: type badge, discount value, menu list, dates, active status, Edit/Toggle/Delete
- Add/Edit modal: name, type, menus multi-select, discount type+value or bundle price, date range, active toggle
- Menu table rows show small promo badge next to item name when a promo is active

---

## Customer Logic (`index.html`)

- Active promotions loaded after menu renders (non-blocking)
- `getEffectivePrice(item)` — calculates discounted price from `PROMO_MAP`
- `calcBundleDiscount()` — checks if all bundle menu_ids in cart, returns discount amount
- Menu cards: red ribbon ("-20%" / "-฿10") or purple "🎁 เซต" badge depending on type
- Discounted items: strikethrough original price + red promo price
- Cart / drawer summary: "🎁 BundleName … -XX ฿" discount line when bundle active
- Order insert: `discount_amount`, `promotion_id`, `subtotal` (before discount), `total_price` (after discount)

---

## Database Changes

| Table/Column | Change |
|---|---|
| `promotions` | New table |
| `promotion_items` | New table (links promotions to menus) |
| `orders.discount_amount` | New column `numeric(10,2) DEFAULT 0` |
| `orders.promotion_id` | New column FK → promotions |

---

## Files Changed

| File | Change |
|---|---|
| `supabase/migrations/018_promotions.sql` | New migration |
| `admin/index.html` | Page tabs, promo section, promo modal, promo JS |
| `index.html` | Promo state, loadPromotions, getEffectivePrice, calcBundleDiscount, card decoration, cart discount |

---

---

# Session 6 — BOM Option Overrides, Promotion System, Bug Fixes
**Session Date:** 2026-06-02
**Scope:** Option-based ingredient deduction, promotion management, price display fixes, reports/accounting data freshness fixes

---

## Feature 1 — BOM Option Override System

### Problem
The BOM deduction (`deduct_bom_for_order`) was menu-level only. When a customer selected options like Matcha Grade "High" or "แยกน้ำแข็ง", the system still deducted default ingredients instead of adjusting for the selected options.

### Solution

**New table: `bom_option_overrides`** — maps option choices to ingredient deduction rules with 3 action types:

| Action | Description | Example |
|---|---|---|
| `replace` | Swap a default ingredient with another | Matcha Grade High → deduct matcha high instead of medium |
| `add` | Inject extra ingredients not in base BOM | แยกน้ำแข็ง → also deduct ถุงซิปน้ำแข็ง |
| `remove` | Skip a default BOM ingredient | ไม่ใส่น้ำแข็ง → skip น้ำแข็ง deduction |

**New helper function: `_do_ingredient_deduction`** — extracted compound/normal deduction logic from `deduct_bom_for_order` to a reusable helper.

**Updated `deduct_bom_for_order`** — now runs 3 phases per order_item:
1. Base BOM, skipping ingredients overridden by chosen options
2. Replace overrides — deduct substitute ingredient (inherits BOM qty if `quantity_used` is null)
3. Add overrides — inject extra ingredients

**Admin UI** (`admin/inventory.html`):
- "⚙ Option Overrides" button appears in BOM tab when a menu is selected
- Modal organized by Option Group → Choice → rules list
- Inline "+Rule" form per choice with conditional fields per action type

### Files
| File | Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New table + helper function + updated `deduct_bom_for_order` |
| `admin/inventory.html` | ⚙ button, overrides modal, CSS, JS |

---

## Feature 2 — Promotion Management System

### Promotion Types

| Type | Behavior |
|---|---|
| `item_discount` | Single/multi menu, % or ฿ off. Effective price applied per item in cart. |
| `bundle` | All menus in set must be in cart → discount applied at order level. |

### Admin UI (`admin/index.html`)
- New page-level tab row: "📋 เมนู" / "🏷 โปรโมชัน"
- Promotions section: card grid showing type badge, discount value, menus, dates, status
- Add/Edit modal: name, type, multi-select menus, discount params, date range, active toggle
- Menu table rows show small promo badge (SALE / 🎁 เซต) next to item name when active

### Customer UI (`index.html`)
- `loadPromotions()` loads active promos non-blocking after menu renders
- `PROMO_MAP` (menuId → promo) and `BUNDLE_PROMOS` array built for O(1) lookup
- `getEffectivePrice(item)` applies discount for card display, modal price, and cart storage
- Red ribbon badge ("-20%" / "-฿10") on discounted card images
- Purple "🎁 เซต" tag on bundle-involved cards
- Cart / checkout drawer shows bundle discount as a separate line

### Order Submission
- `subtotal` = pre-discount total (original prices × qty)
- `discount_amount` = item discounts + bundle discounts
- `total_price` = subtotal − discount_amount (final charged amount)
- `promotion_id` = FK to applied bundle promo (if any)

### Bug: `openAddPromoModal` did nothing
`openPromoModal` called `escHtml()` which was defined in `index.html` but never defined in `admin/index.html`. JS threw `ReferenceError` before reaching `classList.add('show')`. Fixed by adding `escHtml()` to admin/index.html.

### Files
| File | Change |
|---|---|
| `supabase/migrations/018_promotions.sql` | `promotions`, `promotion_items` tables; `orders.discount_amount`, `orders.promotion_id` columns |
| `admin/index.html` | Page tabs, promo card grid, promo modal, `escHtml`, promo JS |
| `index.html` | Promo state globals, `loadPromotions`, `getEffectivePrice`, `calcBundleDiscount`, card decoration, cart discount line, corrected order insert |

---

## Bug Fix — Promotion Price Not Reflected in Cart / Backend

### Root Causes

| # | Bug | Fix |
|---|---|---|
| 1 | `modalBasePrice` in the order modal always showed original price — customer saw ฿100 when discount should show ฿80 | Updated `openModal` to render strikethrough original + red discounted price when promo active |
| 2 | Cart items had no indicator the discount was applied — user couldn't tell if price was original or discounted | Added `original_price` field to cart items; cart row shows ~~100~~ 80 ฿ for discounted items |
| 3 | `orders.subtotal` stored the post-discount total; `discount_amount` was always 0 for item discounts — no visible discount in the DB record | Recalculated: `subtotal` = pre-discount total, `discount_amount` = item discounts + bundle discounts, `total_price` = final |

---

## Bug Fix — Reports / Accounting / Finance Showing Stale Data

### Root Causes

| # | Bug | Affected Pages | Fix |
|---|---|---|---|
| 1 | No Realtime subscription or visibility refresh — pages only loaded data once on init | reports, accounting, finance | Added `postgres_changes` Realtime channel + `visibilitychange` listener to all three pages |
| 2 | Datetime strings `T00:00:00` / `T23:59:59` had no timezone suffix — Supabase treated them as UTC, missing Bangkok orders placed before 7 AM | reports, finance | Added `toUtcISO(dateStr, endOfDay)` helper using `new Date(y, m-1, d, ...).toISOString()` — correctly converts Bangkok local midnight to UTC |
| 3 | `order_items` has no `created_at` column — Menu & Options tab filter silently returned nothing | reports | Fixed: two-step query — fetch order IDs via `orders.created_at`, then filter `order_items` by `order_id IN (...)` |

---

## Bug Fix — Accounting Auto-Record Not Working

### Root Causes

| # | Bug | Fix |
|---|---|---|
| 1 | `accounting_entries` was never added to the `supabase_realtime` publication — Realtime channel subscribed but received zero events | Migration 019: `ALTER PUBLICATION supabase_realtime ADD TABLE accounting_entries` |
| 2 | `markPaid` in `orders.html` used `console.warn` for RPC errors — user had no visibility when `record_order_income` failed | Changed to `showToast(..., true)` so failures appear as visible red toast |
| 3 | No fallback refresh for accounting.html if Realtime unavailable | Added `setInterval(loadEntries, 30000)` — 30-second polling safety net |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `017_bom_option_overrides.sql` | `bom_option_overrides` table + `_do_ingredient_deduction` helper + updated `deduct_bom_for_order` |
| `018_promotions.sql` | `promotions` + `promotion_items` tables; `orders.discount_amount` + `orders.promotion_id` columns |
| `019_accounting_realtime.sql` | Add `accounting_entries` to Realtime publication; re-grant function execute permissions |

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/017_bom_option_overrides.sql` | New — BOM option overrides schema + updated deduction function |
| `supabase/migrations/018_promotions.sql` | New — Promotions schema |
| `supabase/migrations/019_accounting_realtime.sql` | New — Realtime publication + function grants |
| `admin/inventory.html` | ⚙ Option Overrides button + modal + CSS + JS |
| `admin/index.html` | Section tabs, promo card grid, promo modal, escHtml, promo JS |
| `admin/orders.html` | `markPaid` error visibility: console.warn → showToast |
| `admin/reports.html` | `toUtcISO` helper, timezone fix on all 4 queries, `order_items` query fix, Realtime + visibilitychange |
| `admin/accounting.html` | Realtime channel, visibilitychange, 30s polling interval |
| `admin/finance.html` | `cogsFrom/To` timezone fix, Realtime channel, visibilitychange |
| `index.html` | Full promotion system: promo globals, loadPromotions, getEffectivePrice, card decoration, modal price, cart strikethrough, order discount recording |

---

---

# Session 7 — Delivery Fee + Menu Status Toggle
**Session Date:** 2026-06-07
**Scope:** Delivery cost system (DB + frontend + admin config), menu status toggle switch in place of ••• dropdown

---

## Feature 1 — Delivery Cost System

### Problem
Every order was flat no-cost. No delivery fee was recorded in the DB, displayed to the customer, or configurable by the admin.

### Solution

**Migration `020_delivery_fee.sql`:**
- `shops.delivery_fee numeric(10,2) DEFAULT 10` — admin-configurable live setting
- `orders.delivery_fee numeric(10,2) DEFAULT 0` — snapshot at order time so historical records stay accurate

**Customer ordering page (`index.html`):**

| Change | Detail |
|---|---|
| Global `DELIVERY_FEE = 10` | Loaded from `shops.delivery_fee` on page init |
| Cart panel + cart sheet | New `.cart-delivery-line` row (brown, dashed border top) after discount line; `finalTotal += DELIVERY_FEE` |
| Cart FAB | Total in floating button now includes delivery fee |
| Checkout drawer | Delivery fee row in order summary (`renderDrawerSummary`); `finalTotal += DELIVERY_FEE` |
| Order submit | `delivery_fee: DELIVERY_FEE` added to `orders` insert; `total_price = subtotal − discount + DELIVERY_FEE` |
| Translations | `deliveryFee: 'ค่าจัดส่ง'` (TH) / `'Delivery'` (EN) |

**Admin panel (`admin/index.html`):**

| Change | Detail |
|---|---|
| New page tab | "⚙️ ตั้งค่าร้าน" alongside เมนู / โปรโมชัน |
| Settings section | Card with delivery fee number input + "บันทึก" button |
| `saveDeliveryFee()` | Validates input, updates `shops.delivery_fee` via Supabase, shows toast |
| `loadShop()` | Now also loads `delivery_fee` into `currentDeliveryFee` |
| `switchSection('settings')` | Hides page action button; auto-populates input with current value |

**Accounting:** No change needed — `record_order_income` already uses `total_price` which now includes the delivery fee.

---

## Feature 2 — Menu Status Toggle Switch

### Problem
Enabling/disabling a menu item required: clicking `•••` → clicking Disable/Enable in dropdown — 2 clicks and not immediately obvious.

### Solution
Replaced the static Active/Inactive badge in the Status column with a clickable iOS-style toggle switch. Single click flips state immediately.

| Change | Detail |
|---|---|
| CSS `.status-toggle` | 40×22px pill — gray (`#d1d5db`) when off, green (`#22c55e`) when on |
| CSS `.status-toggle-knob` | White circle, 0.18s sliding animation via `left` transition |
| Status column HTML | `<button class="status-toggle [on]">` replaces `<span class="badge">` |
| `•••` dropdown | Disable/Enable item removed — now only Options + Delete remain |
| `toggleActive()` | Reused as-is — no backend change |

---

## Database Migrations (This Session)

| File | Purpose |
|---|---|
| `020_delivery_fee.sql` | `shops.delivery_fee` (configurable default) + `orders.delivery_fee` (order snapshot) |

**Run this migration in Supabase SQL Editor before deploying.**

---

## Files Changed This Session

| File | Type of Change |
|---|---|
| `supabase/migrations/020_delivery_fee.sql` | New — delivery fee columns |
| `index.html` | Delivery fee: global var, cart line, drawer line, FAB total, submit insert, translations |
| `admin/index.html` | Delivery fee: Settings tab + card + save function; status column: toggle switch, ••• dropdown trimmed |

---

# Session 8 — Admin System Mobile Responsiveness Pass
**Session Date:** 2026-06-08 / 2026-06-09
**Scope:** Full systematic mobile audit + patch across all 13 admin pages, targeting phone widths (~375–430px)

---

## Approach

The admin system was originally designed desktop-first. Staff increasingly check orders/inventory/reports from personal phones at the counter, so every admin page got a phone-width pass.

**Decisions made:**
- **CSS-only, page-level changes** — added `@media` blocks inside each page's existing `<style>` block rather than centralizing into `css/design-system.css`. Reason: design-system.css loads *before* each page's own styles, so same-specificity overrides would lose to source order; pages also redefine shared classes (`.modal`, `.table-wrap`, `.sidebar`) with page-specific values, making one shared block fragile.
- **Column-hiding via `nth-child` over card-conversion** — wide tables get 2–4 less-critical columns hidden at ≤640px (e.g. Email/Phone/Contact, Unit/Reorder/Cost) rather than restructuring rows into cards in JS. Keeps every change additive CSS with zero risk to row-rendering logic.
- **Standard breakpoints**: `@media (max-width: 640px)` as the primary phone breakpoint (a few pages already used 700px/720px/768px conventions from earlier sessions — left those in place and layered phone-specific rules on top), with supplementary `400px`/`480px`/`360px` blocks for extra-narrow refinements.

## Pages Patched

| Page | Key changes |
|---|---|
| `admin/index.html` (Menu Mgmt) | Hid drag-handle/Category/Cost/FC% columns on the 9-col menu table (also Photo at 400px); responsive promo-grid, settings-card, page-tabs-row |
| `admin/options.html` | Card-based layout already; compacted `.template-header`, `.choice-row` (drag-handle/name/TH/price/edit/delete), `.add-choice-row` |
| `admin/users.html` | Hid Email column on the 5-col staff table; switched `.table-wrap` to `overflow-x: auto` |
| `admin/printer.html` | Forced `.printer-grid` to single column; modal padding + `.ip-port-row` tweaks |
| `admin/suppliers.html` | Hid Contact/Phone/Email columns on the 6-col supplier table, kept Name/Status/Actions |
| `admin/orders.html` (Order Queue + KDS) | Reduced topbar gap/padding, hid `.topbar-page-label` and `#lastUpdate`, shrank shop-toggle/autoprint controls; added `360px` refinement |
| `admin/dashboard.html` (Sales Dashboard) | Added `hdr-controls` className to the period-picker/live-indicator/clock row so it wraps on narrow screens; shrank seg buttons, live indicator, clock, range-picker popover, KPI values, hours-grid (4→2 cols), category mix (stacked), heatmap grid/labels, customer table |
| `admin/inventory.html` | Hid Unit/Reorder Point/Cost-per-Unit on the ingredients table (kept Name/Stock/Status/Actions); stacked form rows, wrapped BOM/override rows, compacted compound-parts table, full-width overrides modal |
| `admin/reports.html` | Compacted tab bar, constrained date-popover width; hid columns per tab — Sales keeps Date/Order#/Customer/Total/Status, Menu keeps Item/Qty/Revenue/FC%, Inventory keeps Ingredient/Stock/Status/Stock Value |
| `admin/finance.html` | Reduced card padding and P&L value column widths/fonts, constrained date popover, wrapped fixed-cost rows, stacked modal form rows |
| `admin/accounting.html` | Hid Type/Category columns on the journal entries table, constrained date popover, stacked form rows |
| `admin/customers.html` | Already had solid two-panel mobile handling (collapsing CRM layout, mobile-back-button, 2-col stats-bar); added `480px` refinement — stacked form rows, smaller loyalty-points display/profile name, compacted ledger table |
| `admin/purchase-orders.html` | **Fixed an existing mobile bug**: the prior `@media(max-width:640px)` rule hid columns 3+ of the line-item builder, silently removing the price input, notes field, and remove button — making it impossible to set a price or delete a row from a phone. Replaced with a proper stacked-card layout using CSS grid-areas that keeps every field accessible. Also hid Items/Created on the PO list table and Unit/Remaining/Notes on the line-items detail table |

## Notable Find — Purchase Orders Line-Item Bug

`admin/purchase-orders.html` already had a `@media (max-width: 640px)` rule from an earlier session that collapsed `.po-line-row` to a 2-column grid and hid every child past the 2nd (`*:nth-child(n+3) { display: none }`). Since each row is `<select> <input qty> <span unit> <input price> <input note> <button remove>`, this silently hid the **price input, notes field, and remove button** — staff on phones could add ingredients and quantities to a PO but could not set a price or remove a row. Replaced it with a single-column "card" layout per line item using `grid-template-areas`, mapped via `:nth-of-type` on the `<select>`/`<input>`/`<span>`/`<button>` children — every control is now reachable on a phone screen.

## Files Changed This Session

| File | Type of Change |
|---|---|
| `admin/index.html` | Phone media queries — column hiding, grids, tabs |
| `admin/options.html` | Phone media queries — template/choice cards |
| `admin/users.html` | Phone media queries — column hiding, table scroll |
| `admin/printer.html` | Phone media queries — single-column printer grid |
| `admin/suppliers.html` | Phone media queries — column hiding |
| `admin/orders.html` | Phone media queries — topbar compaction |
| `admin/dashboard.html` | Added `hdr-controls` className (JSX) + phone media queries — header controls, KPIs, charts, heatmap, tables |
| `admin/inventory.html` | Phone media queries — column hiding, BOM/override/compound layouts |
| `admin/reports.html` | Phone media queries — column hiding across 3 tabs, popover sizing |
| `admin/finance.html` | Phone media queries — P&L card, fixed-cost rows, popover sizing |
| `admin/accounting.html` | Phone media queries — column hiding, popover sizing |
| `admin/customers.html` | Phone media queries — form rows, loyalty display, ledger table |
| `admin/purchase-orders.html` | **Bug fix** — rebuilt broken mobile line-item layout; phone media queries — column hiding on PO list & line-items tables |

