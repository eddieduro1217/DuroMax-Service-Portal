-- Add order type (Warranty / Paid Order) and message attachment support

alter table public.orders
  add column if not exists order_type text not null default 'paid_order'
  check (order_type in ('warranty','paid_order'));

alter table public.messages
  add column if not exists attachment_path text,
  add column if not exists attachment_name text;

-- Private storage bucket for message attachments (images/docs)
insert into storage.buckets (id, name, public)
values ('message-attachments', 'message-attachments', false)
on conflict (id) do nothing;

-- Files are stored under a path prefixed with the order_id: "{order_id}/{filename}"
-- so access can be scoped to whoever owns that order (or admins).
drop policy if exists "attachments_insert_own_order" on storage.objects;
create policy "attachments_insert_own_order"
  on storage.objects for insert
  with check (
    bucket_id = 'message-attachments'
    and exists (
      select 1 from public.orders o
      where o.id::text = (storage.foldername(name))[1]
        and (o.service_center_id = auth.uid() or public.is_admin())
    )
  );

drop policy if exists "attachments_select_own_order" on storage.objects;
create policy "attachments_select_own_order"
  on storage.objects for select
  using (
    bucket_id = 'message-attachments'
    and exists (
      select 1 from public.orders o
      where o.id::text = (storage.foldername(name))[1]
        and (o.service_center_id = auth.uid() or public.is_admin())
    )
  );
