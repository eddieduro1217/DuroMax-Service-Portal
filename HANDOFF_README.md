# DuroMax / DuroStar Service Center Portal — Session Handoff

## What this project is
A login-gated portal for **authorized service centers**, separate from the public no-login parts
catalog (`DuroMax-DuroStar_Parts_Order`). Built from scratch this session. Eddie's GitHub username:
`eddieduro1217`. Repo: `https://github.com/eddieduro1217/DuroMax-Service-Portal` (public repo, but
access to data is controlled entirely by Supabase Row Level Security, not repo visibility).

**Live URL**: `https://eddieduro1217.github.io/DuroMax-Service-Portal/`

## Stack
- **Frontend**: single-file `index.html`, vanilla JS, no build step — same pattern as the public
  catalog
- **Backend**: Supabase (Postgres + Auth + Storage), free tier
  - Supabase org: `Duro_Parts`
  - Project name: `duromax-service-portal`
  - Project ref: `sulbljseripsdsejuugo` → URL `https://sulbljseripsdsejuugo.supabase.co`
  - Publishable (anon) key is embedded directly in `index.html` — this is intentional and safe;
    all real access control is enforced by RLS policies, not by hiding this key
  - **Secret/service_role key was never shared with Claude and should never be pasted anywhere**

## What's built and working
1. **Auth** — email/password sign-in via Supabase Auth. No self-signup; accounts are created
   manually (admin creates a user in Supabase Auth, then a matching row in `service_centers`).
2. **Two account types**:
   - Regular service center (`is_admin = false`): sees only their own orders/messages
   - Admin (`is_admin = true`): sees all service centers and all orders, can update order status,
     can reply on any thread
3. **Full catalog browsing reused for order creation** — "New Order Request" tab replicates the
   public catalog's UX: Series → Model → figure sections grid → figure detail (diagram + parts
   table) → Add to cart → floating cart panel → submit. This pulls the parts dataset
   (`customer_parts_data.json`, 7,189 rows) embedded directly in this repo's `index.html`, and
   pulls **diagram images cross-origin** from the public catalog's live GitHub Pages URL
   (`https://eddieduro1217.github.io/DuroMax-DuroStar_Parts_Order/images_hotspot/...` and
   `/images/...`) rather than duplicating ~120MB of images into this repo.
4. **Click-to-zoom magnifier** on the figure diagram, ported from the public catalog (circular
   lens, ~2.5x zoom, follows cursor, click to toggle).
5. **Order tracking** — status values: `submitted → in_review → ordered → fulfilled/cancelled`.
   Admins update status from the order detail view.
6. **Order type** — every order is tagged `warranty` or `paid_order` via a required dropdown at
   submission, shown as a small tag throughout the UI.
7. **Two-way messaging per order**, with **file attachments** (images render inline as thumbnails;
   PDFs/docs show as a download link). Attachments are stored in a **private** Supabase Storage
   bucket (`message-attachments`), scoped by RLS so only the order's own service center or an admin
   can access files — signed URLs are generated on read, valid 1 hour.
8. **Visual theme matches the public catalog exactly** — light theme, DuroMax/DuroStar logo header
   (logos pulled from the public catalog's `assets/` folder via cross-origin URL), same card/table/
   button styling, same figure-section grid and detail layout proportions.

## Database schema (see `supabase/migrations/`, run in order via SQL Editor)
- `0001_init.sql` — initial tables: `service_centers`, `orders`, `order_items`, `messages`, all
  with RLS enabled and (at this point) recursive/broken admin-check policies
- `0002_fix_recursion.sql` — **critical fix**: the original admin-check policies queried
  `service_centers` from within a policy defined ON `service_centers`, causing infinite recursion.
  Fixed with a `SECURITY DEFINER` helper function `public.is_admin()` that bypasses RLS when
  checking admin status, and rewired all admin-check policies to use it.
- `0003_grants.sql` — **critical fix**: tables created via the raw SQL Editor don't automatically
  get query permissions granted to Supabase's `authenticated` role (unlike tables created through
  the dashboard's table builder). Had to explicitly `grant select, insert, update, delete ... to
  authenticated` on all four tables.
- `0004_order_type_and_attachments.sql` — added `orders.order_type` (check constraint:
  `warranty`/`paid_order`), added `messages.attachment_path` / `messages.attachment_name`, created
  the private `message-attachments` storage bucket, and added storage RLS policies scoping file
  access to the order's own service center or an admin (path convention:
  `{order_id}/{timestamp}_{filename}`).

**If setting up a fresh Supabase project from scratch, run all four migrations in order — don't
skip 0002/0003, the app will break with "infinite recursion" or "permission denied" errors
otherwise (both were hit and resolved live this session).**

## How to add a new service center account (current process — no self-signup yet)
1. Supabase → Authentication → Users → Add user → Create new user (email + password, **toggle
   "Auto Confirm User" ON** — otherwise login won't work without an email confirmation flow that
   isn't set up)
2. Copy that user's UID
3. Table Editor → `service_centers` → Insert row: paste the UID as `id`, fill in `company_name`,
   `contact_email`, etc. Set `is_admin = true` only for internal staff/admin accounts.

## Known open items / paused work
- **Email invites don't work yet.** Supabase's "Send Invitation" button was tried — the invited
  user record is created correctly in Supabase Auth, but the actual invite email never arrives.
  This is because Supabase's default built-in email sender is a shared, heavily rate-limited
  service meant for testing only, not reliable for real invites. **Fix requires connecting a real
  SMTP provider** (Resend recommended — good free tier) under Project Settings → Authentication →
  SMTP Settings. This was identified but **paused mid-setup** — we got as far as confirming Eddie
  has DNS access for `duromaxpower.com` (needed for domain verification/deliverability), then the
  person asked to pause and revisit later. **Until this is fixed, keep using the manual account
  creation process above** — it works reliably and doesn't depend on email at all.
- **Gorgias integration discussed, not built.** Eddie asked about integrating this portal with
  Gorgias (his support/ticketing platform). Two approaches were laid out:
  - *Lightweight*: order submission triggers an email to the Gorgias-monitored inbox (ties back
    into the paused SMTP work), or a Supabase Edge Function calls Gorgias's ticket-creation API
    directly.
  - *Full two-way sync*: Edge Functions in both directions — portal creates/updates Gorgias
    tickets on order/message activity, and a Gorgias webhook pushes staff replies back into the
    portal's `messages` table.
  Eddie was asked which level he wants and hadn't answered before this handoff was requested —
  **check with him before starting this**. Note: Gorgias API specifics weren't verified against
  live documentation in this session (no web access) — confirm current API/webhook behavior before
  building.
- **No full parts-catalog browsing was skipped** — this was actually built (see "What's built and
  working" above), just noting it in case an earlier draft plan is referenced that described it as
  a "fast follow" — it's done.
- **Pricing/stock are intentionally not shown** — `order_items.unit_price` and `.stock_status`
  columns exist and are reserved for a future update, but are not populated or displayed anywhere
  yet. Eddie confirmed this should stay reference-only for now.

## Scale assessment given (informational, no action needed)
Discussed with Eddie: the current free Supabase tier comfortably handles 50–100 service centers.
The real constraints aren't service-center count but (a) Storage — 1GB free, which fills based on
attachment volume, not headcount, and (b) lack of backups / auto-pause-after-7-days-inactivity on
the free tier, which matters once this becomes something people depend on. Recommended trigger for
upgrading to Supabase Pro ($25/mo): heavy attachment usage, 250+ service centers, or once this
becomes mission-critical — whichever comes first, not a specific number.

## Workflow patterns that worked this session (for future reference)
- Claude's sandboxed bash environment can reach `github.com` / `api.github.com` but **not**
  `supabase.co` — all database/schema work has to go through the person manually pasting SQL into
  Supabase's SQL Editor; Claude cannot connect to the database directly.
- Always verify pushes via the GitHub Contents/Trees API (authenticated), never
  `raw.githubusercontent.com` (CDN lag gives false negatives right after a push).
- Always run a JS syntax check (`new Function()` on the extracted `<script>` block) before pushing
  any edit to `index.html` — it's a large single file with no build step to catch errors otherwise.
- Fine-grained GitHub PATs are scoped per-repo; a new repo needs a fresh PAT even if a similar one
  already exists for another repo.

---

# Session 2 addendum — Home page + documentation sections (2026-09-02)

## What changed

The portal no longer drops you straight into a tab strip after sign-in. `loadProfile()` now calls
`renderHome()`, which renders a **card-tile grid** modelled on the DuroMax Gorgias help center's
"Get more information" layout, restyled in duromaxpower.com's brand. Seven tiles, in Eddie's
requested order:

| Tile | Backing code | Status |
|---|---|---|
| DuroMax Diagrams | `openModelDiagrams()` / `renderCatalogPage()` + existing browse funcs | existing, now reference-only |
| Troubleshooting Guides | `renderTroubleshootingList()` / `openTs()` | NEW |
| Owner's Manuals | `renderManuals('owners')` | NEW |
| Service Manuals | `renderManuals('service')` | NEW |
| Generator Specifications | `renderSpecsList()` / `openSpec()` | NEW |
| My Orders | `renderDashboard('orders')` | existing |
| New Order Request | `renderDashboard('new')` | existing |

Admin accounts (`is_admin = true`) get the same seven tiles plus an **Administration** section with
*All Orders* and *Service Centers*. The old tab strips are still there inside Orders and Admin —
Home is now the hub, tabs are secondary. Every view has a "Back to home" link and the header has a
persistent yellow **Home** button.

`navigate(view)` is the single router (`view` global: `home | diagrams | troubleshooting | owners |
service | specs | orders | new | admin_orders | admin_centers`). It always calls `cleanupCartUI()`
first, so the cart FAB/panel can never leak across views.

## Diagrams vs New Order Request

These two tiles share the same catalog browser, separated by a new global **`browseMode`**:

- `browseMode = 'reference'` (Diagrams) — no cart FAB, no Order column in the parts table, no Add
  buttons. A "Reference view" note and a hand-off card link through to New Order Request.
- `browseMode = 'order'` (New Order Request) — unchanged behaviour: Add to Cart, FAB, cart panel,
  warranty/paid submit.

`renderFigureDetail()` gates both the `<th>Order</th>` header and the whole `<td>` of add-buttons on
`browseMode === 'order'`, and the `if (p.a)` handler wiring is now `if (p.a && browseMode === 'order')`.

## Content data — hardcoded, no schema change

Four new constants sit alongside `PARTS`/`SERIES` in `index.html`. **No migration 0005 was needed** —
deliberately, since Claude's sandbox can't reach `supabase.co` and this avoids another manual
SQL-paste step.

- `OWNERS_MANUALS` — 8 series, 36 models, **35 with a live PDF**
- `SERVICE_MANUALS` — 6 series, 16 models, all 16 with a live PDF
- `SPECS` — 5 series, 18 models, **199 spec tables / 1,450 rows**
- `TROUBLESHOOTING` — 5 guides, full step text + parts-by-symptom tables

All of it was scraped from `duromax-service-center-support.gorgias.help` (73 leaf articles crawled).

### The three content types are NOT the same shape

This matters if you extend it:

1. **Manuals (52 articles) are just links.** Each Gorgias article body contains nothing but one
   hyperlink to a PDF on Shopify's CDN. So the portal skips the Gorgias hop entirely and links
   straight to `cdn.shopify.com/s/files/1/0613/1168/0689/files/...` in a new tab
   (`target="_blank" rel="noopener"`). Always the current published revision, no Gorgias dependency.
2. **Specs (18 articles) are rich tables.** ~10 tables per model (Power Output & Runtime per fuel,
   Engine, Starting System, Safety & Emissions, Electrical, Control Panel & Outlets, Fuel System,
   Dimensions & Weight, Product Information, What's Included). Reproduced natively in-portal.
3. **Troubleshooting (5 articles) are rich step content.** All five share one template — H2 → intro
   → callout → numbered steps → "Potential Part Replacements Based on Symptoms" table → (fuel
   articles only) "Won't Start on ANY Fuel Source" footer. Built as one reusable renderer keyed off
   `anyfuel` and `callout` fields.

### Upstream data problems found (worth fixing in Gorgias)

- `xp28000iht-7921963` (cross-listed under iH) is a **stub with no PDF**. Shows as "Unavailable" in
  the portal — this is the 1 missing manual of 36.
- `xp16000iht-7921962` is **titled** "XP28000iHT" but its slug says XP16000iHT, and the PDF it links
  is `XP28000iHT_manual_revised_07222025_WEB.pdf`. The portal trusts the slug (lists it as
  XP16000iHT) and carries a `flag` field noting the mismatch. **Verify which manual should be there.**
- The parent Generator Specifications category slug is misspelled upstream:
  `generator-speceifications-435199`.
- Model slugs collide across categories — `xp13000hx` exists as both an owner's manual (`-7917259`)
  and a spec sheet (`-7923128`). Any future scrape must key on the numeric article ID, never the slug.

### Model coverage gap (not a bug, a real content gap)

The parts catalog and the documentation cover **different model sets**:

- Diagrams have `XP13750HX`, `XP15500HX`, `XP17500HX`, `XP13750HXT`, `XP17500HXT`, `XP9000iH` —
  **no manuals or specs exist** for these upstream.
- Manuals cover `DX`, `E`, and `X` series models that have **no diagrams** in the catalog.

The portal degrades gracefully (a spec sheet only shows a "Parts diagrams" button when
`SERIES` actually contains that model; a missing manual shows "Unavailable"), but the gaps are real
content gaps on DuroMax's side.

## Brand restyle — whole portal

Retheme, not a repaint of one screen. Tokens read from duromaxpower.com's **live computed CSS**:

```
--blue      #0F4B91   header, footer, links, primary CTAs, table heads, step numerals
--blue-hi   #2A65AF   hover
--ink       #1C1D1D   dark industrial bands (login hero, home hero, tile art)
--near-black #111111  .btn-primary (matches their site's black buttons)
--yellow    #FFCC33   accents: Home button, tile icons, login headline highlight
--green     #49A75B   retained for Add-to-Cart / submit only
```

Plus **Saira 600/700** from Google Fonts for all headings and buttons, and **`border-radius: 0`
everywhere** except form inputs (`4px`, matching their site). The old theme's green primary
(`#3E9654`), 10px rounded corners and near-black header were all replaced.

Header is now solid brand blue and sticky. `renderLogin()` got a dark hero band with a yellow
accent and an Enter-to-submit handler on the password field.

**Anchors used as buttons** (`a.btn-blue`, `a.btn-secondary` on the spec sheet's manual links) need
an explicit base rule — `button{}` styles don't cascade to `<a>`. That rule is in the stylesheet;
don't remove it or those turn into bare text.

## How this build was produced (reproducible)

Not hand-edited. `build/build.py` applies **20 exact-match string patches** to the original
`index.html` and fails loudly (`sys.exit(1)`) if any anchor doesn't match exactly once. Source
inputs live beside it:

```
build/build.py      the patch script — run it against a pristine index.html
build/style.css     the full replacement stylesheet
build/app_new.js    all new render functions (home, troubleshooting, manuals, specs, catalog page)
build/mock.js       offline Supabase stub, test harness only — NEVER ships
build/smoke.js      Playwright suite, 65 assertions
data/*.json         the five scraped datasets
index.html.orig     pristine pre-change copy
```

To re-apply after an upstream edit: `cp index.html.orig index.html && python3 build/build.py`.

## Validation run

- `new Function()` syntax check on the extracted script block — **pass** (1.38M chars)
- Data integrity — PARTS 7,189 rows / SERIES 8 series, 30 models / all new counts as listed above
- NetSuite leakage guard (`'id' | 'u' | 's' in p`) — **pass, none present**
- All 51 PDF URLs verified to be `https://cdn.shopify.com/` — **pass**
- Playwright, stubbed Supabase, 5 scenarios (login / home / all 7 sections / admin / 390px mobile) —
  **65 passed, 0 failed, zero console errors**
- Screenshots captured for login, home, troubleshooting, owner's manuals, specs, diagrams,
  new-order-with-cart, admin, mobile

Note the smoke suite filters out `eddieduro1217.github.io`, `cdn.shopify.com` and `fonts.g*` console
noise — those are unreachable from the sandbox by design, not app errors.

## Still open (unchanged from session 1)

- **Not pushed.** Needs a fresh fine-grained PAT scoped to `DuroMax-Service-Portal` with Contents
  read/write. Verify via the GitHub Contents/Trees API after pushing, never `raw.githubusercontent.com`.
- **SMTP/email invites still broken** — manual account creation still the working path.
- **Gorgias API integration still not built** — Eddie hasn't picked lightweight vs full two-way sync.
  Note this session only *scraped* the public help center; no API was used.
- Pricing/stock still intentionally hidden.
