# DuroMax / DuroStar Service Center Portal

Login-gated portal for authorized DuroMax/DuroStar service centers. Separate from the public
customer parts catalog (`DuroMax-DuroStar_Parts_Order`) — that one stays open, no-login, no accounts.

## What this is
- Service centers sign in and submit order requests (model, part/description, qty)
- Track order status (submitted → in_review → ordered → fulfilled/cancelled)
- Two-way messaging per order between the service center and the DuroMax team
- Admin accounts (`is_admin = true` in `service_centers`) can see all orders/centers, update status, and reply to any thread

## Stack
- Single-file `index.html` — no build step, served as-is (GitHub Pages or any static host)
- [Supabase](https://supabase.com) for auth + Postgres database + row-level security
- Row-level security ensures each service center only ever sees their own orders/messages

## Adding a new service center account
No self-signup yet — accounts are created manually:
1. Supabase dashboard → Authentication → Users → Add user (email + password, or send invite)
2. Copy that user's ID
3. Insert a row into the `service_centers` table with that ID, company name, and contact info

## Schema
See `supabase/migrations/0001_init.sql` for the full schema (tables: `service_centers`, `orders`,
`order_items`, `messages`), run manually via the Supabase SQL Editor.

## Config
Supabase Project URL and anon/publishable key are embedded directly in `index.html` (`SUPABASE_URL`,
`SUPABASE_ANON_KEY` constants near the top of the `<script>` block) — this is safe, as access control
is enforced by row-level security policies, not by hiding these values.

## Known open items
- No self-signup flow yet (admin-created accounts only)
- No pricing/live stock shown yet — reference-only for now, with `unit_price`/`stock_status` columns
  reserved on `order_items` for a future update
- New Order form uses manual model/part entry; integrating full parts-catalog browsing (like the public
  site) into order creation is a planned fast-follow
