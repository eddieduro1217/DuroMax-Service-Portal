-- Grant base table permissions to the `authenticated` role.
-- RLS policies control WHICH rows are visible/writable; these grants control
-- whether the role can attempt the operation at all. Both are required.

grant usage on schema public to authenticated;

grant select, update on public.service_centers to authenticated;
grant select, insert, update on public.orders to authenticated;
grant select, insert on public.order_items to authenticated;
grant select, insert on public.messages to authenticated;
