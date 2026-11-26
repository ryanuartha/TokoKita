create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 40),
  recipient_name text not null check (
    char_length(btrim(recipient_name)) between 1 and 100
  ),
  phone text not null default '',
  address text not null check (char_length(btrim(address)) >= 8),
  latitude double precision,
  longitude double precision,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create index if not exists customer_addresses_user_default_idx
  on public.customer_addresses (user_id, is_default desc, updated_at desc);

create unique index if not exists customer_addresses_one_default_per_user_idx
  on public.customer_addresses (user_id)
  where is_default;

alter table public.customer_addresses enable row level security;

drop policy if exists "Customers read own addresses"
  on public.customer_addresses;
create policy "Customers read own addresses"
  on public.customer_addresses for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Customers add own addresses"
  on public.customer_addresses;
create policy "Customers add own addresses"
  on public.customer_addresses for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Customers update own addresses"
  on public.customer_addresses;
create policy "Customers update own addresses"
  on public.customer_addresses for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Customers delete own addresses"
  on public.customer_addresses;
create policy "Customers delete own addresses"
  on public.customer_addresses for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.customer_addresses from anon, authenticated;
grant select, insert, update, delete on public.customer_addresses
  to authenticated;

create or replace function public.set_default_customer_address(
  p_address_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Login diperlukan';
  end if;

  if not exists (
    select 1
    from public.customer_addresses
    where id = p_address_id and user_id = auth.uid()
  ) then
    raise exception 'Alamat tidak ditemukan';
  end if;

  update public.customer_addresses
  set is_default = false, updated_at = now()
  where user_id = auth.uid() and is_default;

  update public.customer_addresses
  set is_default = true, updated_at = now()
  where id = p_address_id and user_id = auth.uid();
end;
$$;

revoke all on function public.set_default_customer_address(uuid)
  from public, anon;
grant execute on function public.set_default_customer_address(uuid)
  to authenticated;
