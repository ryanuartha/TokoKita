drop policy if exists "Admins read all products" on public.products;
create policy "Admins read all products"
  on public.products for select to authenticated
  using ((select public.current_user_is_admin()));

drop policy if exists "Admins update product inventory" on public.products;
create policy "Admins update product inventory"
  on public.products for update to authenticated
  using ((select public.current_user_is_admin()))
  with check ((select public.current_user_is_admin()));

grant update (stock, updated_at) on table public.products to authenticated;
