-- Fix infinite recursion: the admin-check policies queried service_centers
-- from within a policy ON service_centers, triggering the policy again.
-- Fix: a SECURITY DEFINER helper function that bypasses RLS when checking admin status.

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_admin from public.service_centers where id = auth.uid()), false);
$$;

-- Replace the recursive policy on service_centers
drop policy if exists "service_centers_admin_all" on public.service_centers;
create policy "service_centers_admin_all"
  on public.service_centers for all
  using (public.is_admin());

-- Replace the other admin-check policies to use the same safe function
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
  on public.orders for select
  using (service_center_id = auth.uid() or public.is_admin());

drop policy if exists "orders_update_admin_only" on public.orders;
create policy "orders_update_admin_only"
  on public.orders for update
  using (public.is_admin());

drop policy if exists "order_items_select_via_order" on public.order_items;
create policy "order_items_select_via_order"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.service_center_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists "messages_select_own_thread" on public.messages;
create policy "messages_select_own_thread"
  on public.messages for select
  using (service_center_id = auth.uid() or public.is_admin());

drop policy if exists "messages_insert_own_thread" on public.messages;
create policy "messages_insert_own_thread"
  on public.messages for insert
  with check (
    sender_id = auth.uid()
    and (service_center_id = auth.uid() or public.is_admin())
  );
