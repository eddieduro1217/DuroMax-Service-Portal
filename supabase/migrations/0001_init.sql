-- DuroMax/DuroStar Service Center Portal — initial schema
-- Every table has RLS enabled; service centers can only see their own rows.
-- Admin/staff access is handled via a separate `is_admin` claim check.

-- =========================================================
-- service_centers: one row per authorized service center account
-- =========================================================
create table public.service_centers (
  id uuid primary key references auth.users(id) on delete cascade,
  company_name text not null,
  contact_name text,
  contact_email text not null,
  contact_phone text,
  is_active boolean not null default true,
  is_admin boolean not null default false, -- true for internal staff accounts
  created_at timestamptz not null default now()
);

alter table public.service_centers enable row level security;

-- A service center can read/update only its own row
create policy "service_centers_select_own"
  on public.service_centers for select
  using (auth.uid() = id);

create policy "service_centers_update_own"
  on public.service_centers for update
  using (auth.uid() = id);

-- Admins can see/manage all service center rows
create policy "service_centers_admin_all"
  on public.service_centers for all
  using (
    exists (
      select 1 from public.service_centers sc
      where sc.id = auth.uid() and sc.is_admin = true
    )
  );

-- =========================================================
-- orders: one row per order request
-- =========================================================
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  service_center_id uuid not null references public.service_centers(id) on delete cascade,
  order_ref text not null unique, -- e.g. PR-YYYYMMDD-####, same format as public site
  status text not null default 'submitted', -- submitted | in_review | ordered | fulfilled | cancelled
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.orders enable row level security;

create policy "orders_select_own"
  on public.orders for select
  using (
    service_center_id = auth.uid()
    or exists (select 1 from public.service_centers sc where sc.id = auth.uid() and sc.is_admin = true)
  );

create policy "orders_insert_own"
  on public.orders for insert
  with check (service_center_id = auth.uid());

create policy "orders_update_admin_only"
  on public.orders for update
  using (exists (select 1 from public.service_centers sc where sc.id = auth.uid() and sc.is_admin = true));

-- =========================================================
-- order_items: line items per order (part/qty, reference-only, no pricing yet)
-- =========================================================
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  model text not null,
  figure_number text,
  ref_number text,
  part_number text,
  description text,
  qty integer not null default 1,
  -- reserved for future use, not populated yet:
  unit_price numeric,
  stock_status text
);

alter table public.order_items enable row level security;

create policy "order_items_select_via_order"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.service_center_id = auth.uid()
             or exists (select 1 from public.service_centers sc where sc.id = auth.uid() and sc.is_admin = true))
    )
  );

create policy "order_items_insert_via_order"
  on public.order_items for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_id and o.service_center_id = auth.uid()
    )
  );

-- =========================================================
-- messages: two-way thread, scoped to an order (or general if order_id is null)
-- =========================================================
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade, -- nullable = general message, not tied to one order
  service_center_id uuid not null references public.service_centers(id) on delete cascade,
  sender_id uuid not null references public.service_centers(id), -- either the service center or an admin/staff row
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.messages enable row level security;

create policy "messages_select_own_thread"
  on public.messages for select
  using (
    service_center_id = auth.uid()
    or exists (select 1 from public.service_centers sc where sc.id = auth.uid() and sc.is_admin = true)
  );

create policy "messages_insert_own_thread"
  on public.messages for insert
  with check (
    sender_id = auth.uid()
    and (
      service_center_id = auth.uid()
      or exists (select 1 from public.service_centers sc where sc.id = auth.uid() and sc.is_admin = true)
    )
  );

-- =========================================================
-- updated_at trigger for orders
-- =========================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();
