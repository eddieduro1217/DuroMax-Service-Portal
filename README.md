# DuroMax / DuroStar Service Center Portal

Login-gated portal for authorized DuroMax/DuroStar service centers. Separate from the public
customer parts catalog (`DuroMax-DuroStar_Parts_Order`) — that one stays open, no-login, no accounts.

## What this is

After signing in, service centers land on a **home page** — a DuroMax banner masthead over
**seven tiles**, each with its own product thumbnail:

| Tile | What it does |
|---|---|
| **DuroMax Diagrams** | Exploded parts diagrams by series/model with click-to-zoom. Reference only — no cart. |
| **Troubleshooting Guides** | 5 step-by-step diagnostic guides with parts-to-replace-by-symptom tables. |
| **Owner's Manuals** | 35 factory owner's manuals across 8 series. Opens the official PDF in a new tab. |
| **Service Manuals** | 16 service/repair manuals across 6 series. Opens the official PDF in a new tab. |
| **Generator Specifications** | Full published specs for 18 models — 199 tables of output, engine, electrical, outlets, fuel and dimensions. |
| **My Orders** | Track status (submitted → in_review → ordered → fulfilled/cancelled) and message the DuroMax team per order, with attachments. |
| **New Order Request** | Browse diagrams, build a parts list, submit as a warranty or paid order request. |

Admin accounts (`is_admin = true` in `service_centers`) additionally see an **Administration**
section — all orders from all centers, status updates, replies on any thread, and the service
center roster.

Documentation content (manuals, specs, troubleshooting) is embedded in `index.html` as the
`OWNERS_MANUALS`, `SERVICE_MANUALS`, `SPECS` and `TROUBLESHOOTING` constants — no database tables,
no extra network calls. Manual PDFs are linked directly from DuroMax's Shopify CDN so they're
always the current published revision.

Every screen carries two navigation buttons — **Back to previous page** (a real history stack, so
it unwinds whatever trail you took, including figure drill-downs) and **Back to home**. The header
also keeps a persistent Home button.

## Repo layout

```
index.html      the whole app (generated - see "Rebuilding" below)
assets/         8 JPEGs: 7 tile thumbnails + the home banner
build/          build script, stylesheet, new-section code, validation suites
data/           the 5 scraped datasets (manuals, specs, troubleshooting)
supabase/       migrations 0001-0004, run in order
```

`assets/` must sit at the repo root. If those files ever end up flattened into the root instead,
the app falls back to the bare filename automatically, and if the image still can't be found each
tile shows its original SVG icon rather than a broken image.

## Look and feel

Themed to match [duromaxpower.com](https://www.duromaxpower.com): DuroMax blue `#0F4B91`, Saira Bold
headings, square corners throughout, `#FFCC33` yellow accents, dark industrial bands on the login
and home heroes.

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

## Rebuilding index.html

`index.html` is generated, not hand-edited. `build/build.py` applies exact-match patches to the
**pre-home-page base** using `build/style.css`, `build/app_new.js` and the datasets in `data/`.

The base is commit `28938f2` (the last commit before the home page landed), so restore it from git
rather than keeping a duplicate copy in the repo:

```bash
git show 28938f2:index.html > index.html
python3 build/build.py
```

It fails loudly if any patch anchor doesn't match exactly once. Validate before pushing:

```bash
node build/checks.js        # JS syntax + data integrity + NetSuite leakage guard
node build/smoke.js         # Playwright, 65 assertions (needs the local test harness)
```

`build/mock.js` is an offline Supabase stub used **only** by the test harness — it must never be
referenced from the shipped `index.html`.

## Known open items
- No self-signup flow yet (admin-created accounts only)
- No pricing/live stock shown yet — reference-only for now, with `unit_price`/`stock_status` columns
  reserved on `order_items` for a future update
- **1 owner's manual missing upstream** (XP28000iHT — the Gorgias article is a stub with no PDF),
  and the XP16000iHT article links the XP28000iHT manual. Both need fixing in Gorgias, not here.
- **Model coverage gap**: diagrams exist for XP13750HX / XP15500HX / XP17500HX / XP13750HXT /
  XP17500HXT / XP9000iH with no manuals or specs published; manuals exist for DX / E / X series
  models with no diagrams. The UI degrades gracefully but the content gaps are real.
- Gorgias ticketing integration discussed but not built — content here was scraped from the public
  help center, no API involved.
