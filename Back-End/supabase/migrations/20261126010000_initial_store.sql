create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  price integer not null check (price > 0),
  stock integer not null default 0 check (stock >= 0),
  image_asset text not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.products (id, name, category, price, image_asset)
values
  ('EL-001', 'Smartphone Nova X Pro 5G', 'Elektronik', 3499000, 'assets/images/el_001.jpg'),
  ('EL-002', 'Headphone Studio Wireless', 'Elektronik', 899000, 'assets/images/el_002.jpg'),
  ('EL-003', 'Smartwatch Fit Active GT', 'Elektronik', 1299000, 'assets/images/el_003.jpg'),
  ('EL-004', 'Speaker Mini Portable Bass+', 'Elektronik', 450000, 'assets/images/el_004.jpg'),
  ('EL-005', 'Tablet Ultra Pad Pro 11"', 'Elektronik', 4899000, 'assets/images/el_005.jpg'),
  ('EL-006', 'Earbuds True Wireless ANC Pro', 'Elektronik', 599000, 'assets/images/el_006.jpg'),
  ('PK-001', 'Hoodie Classic Fleece Premium', 'Pakaian', 249000, 'assets/images/pk_001.jpg'),
  ('PK-002', 'Kaos Basic Heavyweight Cotton', 'Pakaian', 89000, 'assets/images/pk_002.jpg'),
  ('PK-003', 'Jaket Urban Windproof Outer', 'Pakaian', 379000, 'assets/images/pk_003.jpg'),
  ('PK-004', 'Sneakers Daily Comfort Runner', 'Pakaian', 499000, 'assets/images/pk_004.jpg'),
  ('PK-005', 'Kemeja Linen Slim Fit Casual', 'Pakaian', 199000, 'assets/images/pk_005.jpg'),
  ('PK-006', 'Celana Chino Stretch Workwear', 'Pakaian', 229000, 'assets/images/pk_006.jpg'),
  ('AK-001', 'Kacamata Polarized Aviator HD', 'Aksesori', 179000, 'assets/images/ak_001.jpg'),
  ('AK-002', 'Ransel Laptop Waterproof 20L', 'Aksesori', 329000, 'assets/images/ak_002.jpg'),
  ('AK-003', 'Dompet Kulit Genuine Bifold', 'Aksesori', 159000, 'assets/images/ak_003.jpg'),
  ('AK-004', 'Jam Tangan Analog Minimalis', 'Aksesori', 489000, 'assets/images/ak_004.jpg'),
  ('AK-005', 'Topi Baseball Canvas Vintage', 'Aksesori', 69000, 'assets/images/ak_005.jpg'),
  ('AK-006', 'Botol Minum Stainless Thermal', 'Aksesori', 139000, 'assets/images/ak_006.jpg')
on conflict (id) do nothing;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  display_id text not null unique,
  user_id uuid not null references auth.users (id),
  status text not null check (
    status in ('pending_payment', 'processing', 'shipped', 'ready_for_pickup', 'completed', 'cancelled')
  ),
  payment_status text not null check (
    payment_status in ('pending', 'paid', 'cash_due', 'store_due', 'failed', 'cancelled')
  ),
  payment_method text not null check (
    payment_method in ('qris', 'gopay', 'bank_transfer', 'credit_card', 'cod', 'store_payment')
  ),
  fulfillment_method text not null check (
    fulfillment_method in ('courier', 'store_pickup')
  ),
  shipping_address text not null default '',
  subtotal integer not null check (subtotal >= 0),
  discount integer not null default 0 check (discount >= 0),
  shipping_fee integer not null default 0 check (shipping_fee >= 0),
  total_amount integer not null check (total_amount >= 0),
  voucher_code text,
  snap_token text,
  snap_redirect_url text,
  midtrans_transaction_id text,
  expires_at timestamptz,
  tracking_number text,
  pickup_code text,
  delivered_at timestamptz,
  completed_at timestamptz,
  stock_released boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id text not null references public.products (id),
  product_name text not null,
  image_asset text not null,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price > 0),
  line_total integer not null check (line_total > 0)
);

create index if not exists orders_user_created_idx
  on public.orders (user_id, created_at desc);
create index if not exists orders_status_created_idx
  on public.orders (status, created_at desc);
create index if not exists order_items_order_id_idx
  on public.order_items (order_id);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Users read own profile" on public.profiles;
create policy "Users read own profile"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or (select public.current_user_is_admin())
  );

drop policy if exists "Anyone reads active products" on public.products;
create policy "Anyone reads active products"
  on public.products for select to anon, authenticated
  using (active);

drop policy if exists "Customers and admins read orders" on public.orders;
create policy "Customers and admins read orders"
  on public.orders for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.current_user_is_admin())
  );

drop policy if exists "Customers and admins read order items" on public.order_items;
create policy "Customers and admins read order items"
  on public.order_items for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (
          o.user_id = (select auth.uid())
          or (select public.current_user_is_admin())
        )
    )
  );

revoke insert, update, delete on public.profiles from anon, authenticated;
revoke insert, update, delete on public.products from anon, authenticated;
revoke insert, update, delete on public.orders from anon, authenticated;
revoke insert, update, delete on public.order_items from anon, authenticated;
grant select on public.profiles, public.products, public.orders, public.order_items
  to authenticated;
grant select on public.products to anon;
revoke all on function public.current_user_is_admin() from public, anon;
grant execute on function public.current_user_is_admin() to authenticated, service_role;

create or replace function public.create_store_order(
  p_user_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_fulfillment_method text,
  p_shipping_address text,
  p_voucher_code text
)
returns table (
  order_id uuid,
  display_id text,
  total_amount integer,
  expires_at timestamptz,
  item_details jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item record;
  v_product public.products%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_display_id text := 'TK-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  v_subtotal integer := 0;
  v_discount integer := 0;
  v_shipping_fee integer := 0;
  v_total integer;
  v_expires_at timestamptz;
  v_status text;
  v_payment_status text;
  v_snapshot jsonb := '[]'::jsonb;
  v_count integer := 0;
begin
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Keranjang kosong';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Keranjang kosong';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_items) as item(product_id text, quantity integer)
    group by item.product_id
    having count(*) > 1
  ) then
    raise exception 'Produk duplikat dalam pesanan';
  end if;
  if p_payment_method not in ('qris', 'gopay', 'bank_transfer', 'credit_card', 'cod', 'store_payment') then
    raise exception 'Metode pembayaran tidak didukung';
  end if;
  if p_fulfillment_method not in ('courier', 'store_pickup') then
    raise exception 'Metode penerimaan tidak didukung';
  end if;
  if p_fulfillment_method = 'courier' and coalesce(trim(p_shipping_address), '') = '' then
    raise exception 'Alamat pengiriman wajib diisi';
  end if;
  if p_fulfillment_method = 'store_pickup' and p_payment_method = 'cod' then
    raise exception 'Gunakan pembayaran di toko untuk pickup';
  end if;
  if p_fulfillment_method = 'courier' and p_payment_method = 'store_payment' then
    raise exception 'Pembayaran di toko hanya tersedia untuk pickup';
  end if;

  for v_item in
    select item.product_id, item.quantity
    from jsonb_to_recordset(p_items) as item(product_id text, quantity integer)
    order by item.product_id
  loop
    if v_item.product_id is null or v_item.quantity is null or v_item.quantity < 1 then
      raise exception 'Item pesanan tidak valid';
    end if;
    select * into v_product
    from public.products p
    where p.id = v_item.product_id and p.active
    for update;
    if not found then
      raise exception 'Produk tidak tersedia: %', v_item.product_id;
    end if;
    if v_product.stock < v_item.quantity then
      raise exception 'Stok tidak cukup untuk produk: %', v_product.name;
    end if;

    update public.products
    set stock = stock - v_item.quantity, updated_at = now()
    where id = v_product.id;
    v_subtotal := v_subtotal + (v_product.price * v_item.quantity);
    v_count := v_count + 1;
    v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object(
      'id', v_product.id,
      'price', v_product.price,
      'quantity', v_item.quantity,
      'name', v_product.name,
      'image_asset', v_product.image_asset
    ));
  end loop;

  if v_count <> jsonb_array_length(p_items) then
    raise exception 'Ada item pesanan yang duplikat atau tidak valid';
  end if;

  if p_voucher_code = 'DISKON50' then
    v_discount := least(15000, v_subtotal);
  elsif p_voucher_code = 'PROMOAKHIRTAHUN' then
    v_discount := least(25000, v_subtotal);
  elsif p_voucher_code not in ('', 'Tanpa Voucher', 'BEBASONGKIR') then
    raise exception 'Voucher tidak valid';
  end if;

  v_total := greatest(0, v_subtotal - v_discount + v_shipping_fee);
  v_expires_at := case
    when p_payment_method = 'qris' or p_payment_method = 'gopay'
      then now() + interval '15 minutes'
    when p_payment_method = 'bank_transfer'
      then now() + interval '24 hours'
    when p_payment_method = 'credit_card'
      then now() + interval '15 minutes'
    else null
  end;
  v_status := case
    when p_payment_method in ('cod', 'store_payment') then 'processing'
    else 'pending_payment'
  end;
  v_payment_status := case
    when p_payment_method = 'cod' then 'cash_due'
    when p_payment_method = 'store_payment' then 'store_due'
    else 'pending'
  end;

  insert into public.orders (
    id, display_id, user_id, status, payment_status, payment_method,
    fulfillment_method, shipping_address, subtotal, discount, shipping_fee,
    total_amount, voucher_code, expires_at, pickup_code
  ) values (
    v_order_id, v_display_id, p_user_id, v_status, v_payment_status,
    p_payment_method, p_fulfillment_method, coalesce(p_shipping_address, ''),
    v_subtotal, v_discount, v_shipping_fee, v_total, nullif(p_voucher_code, ''),
    v_expires_at,
    case when p_fulfillment_method = 'store_pickup'
      then upper(substr(replace(v_order_id::text, '-', ''), 1, 6))
      else null
    end
  );

  for v_item in
    select item.product_id, item.quantity
    from jsonb_to_recordset(p_items) as item(product_id text, quantity integer)
  loop
    select * into v_product from public.products where id = v_item.product_id;
    insert into public.order_items (
      order_id, product_id, product_name, image_asset, quantity, unit_price, line_total
    ) values (
      v_order_id, v_product.id, v_product.name, v_product.image_asset,
      v_item.quantity, v_product.price, v_product.price * v_item.quantity
    );
  end loop;

  return query select v_order_id, v_display_id, v_total, v_expires_at, v_snapshot;
end;
$$;

create or replace function public.apply_midtrans_status(
  p_order_id uuid,
  p_transaction_status text,
  p_fraud_status text,
  p_transaction_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Pesanan tidak ditemukan';
  end if;

  if p_transaction_status in ('settlement', 'capture') and
      (p_transaction_status <> 'capture' or p_fraud_status = 'accept') then
    if v_order.status = 'pending_payment' then
      update public.orders
      set status = 'processing', payment_status = 'paid',
          midtrans_transaction_id = p_transaction_id, updated_at = now()
      where id = p_order_id;
    end if;
  elsif p_transaction_status in ('expire', 'cancel', 'deny') and
      v_order.status = 'pending_payment' then
    perform public.release_order_stock(p_order_id);
    update public.orders
    set status = 'cancelled', payment_status = 'cancelled',
        midtrans_transaction_id = p_transaction_id, updated_at = now()
    where id = p_order_id;
  elsif p_transaction_status = 'pending' then
    update public.orders
    set midtrans_transaction_id = p_transaction_id, updated_at = now()
    where id = p_order_id;
  end if;
end;
$$;

create or replace function public.release_order_stock(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.products p
  set stock = p.stock + items.quantity, updated_at = now()
  from (
    select product_id, sum(quantity)::integer as quantity
    from public.order_items
    where order_id = p_order_id
    group by product_id
  ) items
  where p.id = items.product_id
    and exists (
      select 1 from public.orders o
      where o.id = p_order_id and o.stock_released = false
    );
  update public.orders set stock_released = true, updated_at = now()
  where id = p_order_id and stock_released = false;
end;
$$;

create or replace function public.transition_store_order(
  p_order_id uuid,
  p_action text,
  p_tracking_number text default null,
  p_actor_id uuid default null,
  p_is_admin boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Pesanan tidak ditemukan';
  end if;

  if p_action = 'cancel' then
    if v_order.user_id <> p_actor_id and not p_is_admin then
      raise exception 'Tidak berwenang membatalkan pesanan ini';
    end if;
    if v_order.status <> 'pending_payment' and not (
      v_order.status = 'processing'
      and v_order.payment_status in ('cash_due', 'store_due')
    ) then
      raise exception 'Pesanan tidak dapat dibatalkan pada status ini';
    end if;
    perform public.release_order_stock(p_order_id);
    update public.orders
    set status = 'cancelled', payment_status = 'cancelled', updated_at = now()
    where id = p_order_id;
  elsif p_action = 'dispatch' then
    if not p_is_admin then raise exception 'Akses admin diperlukan'; end if;
    if v_order.status <> 'processing' then raise exception 'Status pesanan tidak valid'; end if;
    if v_order.fulfillment_method = 'store_pickup' then
      update public.orders
      set status = 'ready_for_pickup', updated_at = now()
      where id = p_order_id;
    else
      if coalesce(trim(p_tracking_number), '') = '' then
        raise exception 'Nomor resi wajib diisi';
      end if;
      update public.orders
      set status = 'shipped', tracking_number = trim(p_tracking_number),
          updated_at = now()
      where id = p_order_id;
    end if;
  elsif p_action = 'mark_delivered' then
    if not p_is_admin then raise exception 'Akses admin diperlukan'; end if;
    if v_order.status <> 'shipped' or v_order.delivered_at is not null then
      raise exception 'Status pesanan tidak valid';
    end if;
    update public.orders
    set delivered_at = now(), updated_at = now()
    where id = p_order_id;
  elsif p_action = 'confirm_received' then
    if v_order.user_id <> p_actor_id then raise exception 'Bukan pemilik pesanan'; end if;
    if v_order.status <> 'shipped' or v_order.delivered_at is null then
      raise exception 'Pesanan belum dapat dikonfirmasi';
    end if;
    update public.orders
    set status = 'completed', completed_at = now(), updated_at = now()
    where id = p_order_id;
  elsif p_action = 'handover_pickup' then
    if not p_is_admin then raise exception 'Akses admin diperlukan'; end if;
    if v_order.status <> 'ready_for_pickup' then raise exception 'Status pesanan tidak valid'; end if;
    update public.orders
    set status = 'completed',
        payment_status = case
          when payment_status = 'store_due' then 'paid'
          else payment_status
        end,
        completed_at = now(), updated_at = now()
    where id = p_order_id;
  elsif p_action = 'confirm_cash_payment' then
    if not p_is_admin then raise exception 'Akses admin diperlukan'; end if;
    if v_order.payment_status <> 'cash_due'
        or v_order.status not in ('shipped', 'completed') then
      raise exception 'Pembayaran COD belum dapat dikonfirmasi';
    end if;
    update public.orders
    set payment_status = 'paid', updated_at = now()
    where id = p_order_id;
  else
    raise exception 'Aksi tidak dikenali';
  end if;
end;
$$;

revoke all on function public.create_store_order(uuid, jsonb, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.apply_midtrans_status(uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.release_order_stock(uuid)
  from public, anon, authenticated;
revoke all on function public.transition_store_order(uuid, text, text, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.create_store_order(uuid, jsonb, text, text, text, text)
  to service_role;
grant execute on function public.apply_midtrans_status(uuid, text, text, text)
  to service_role;
grant execute on function public.release_order_stock(uuid)
  to service_role;
grant execute on function public.transition_store_order(uuid, text, text, uuid, boolean)
  to service_role;
