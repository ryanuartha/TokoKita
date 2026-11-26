alter table public.order_items
  add column variant_size text
    check (variant_size is null or variant_size in ('S', 'M', 'L', 'XL')),
  add column variant_color text
    check (variant_color is null or variant_color in ('Hitam', 'Putih', 'Navy', 'Abu-abu'));

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
    from jsonb_to_recordset(p_items) as item(
      product_id text,
      quantity integer,
      variant_size text,
      variant_color text
    )
    group by
      item.product_id,
      coalesce(item.variant_size, ''),
      coalesce(item.variant_color, '')
    having count(*) > 1
  ) then
    raise exception 'Varian produk duplikat dalam pesanan';
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
    select item.product_id, item.quantity, item.variant_size, item.variant_color
    from jsonb_to_recordset(p_items) as item(
      product_id text,
      quantity integer,
      variant_size text,
      variant_color text
    )
    order by item.product_id, item.variant_size, item.variant_color
  loop
    if v_item.product_id is null or v_item.quantity is null or v_item.quantity < 1 then
      raise exception 'Item pesanan tidak valid';
    end if;
    if v_item.variant_size is not null
      and v_item.variant_size not in ('S', 'M', 'L', 'XL') then
      raise exception 'Ukuran produk tidak valid';
    end if;
    if v_item.variant_color is not null
      and v_item.variant_color not in ('Hitam', 'Putih', 'Navy', 'Abu-abu') then
      raise exception 'Warna produk tidak valid';
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
      'image_asset', v_product.image_asset,
      'variant_size', v_item.variant_size,
      'variant_color', v_item.variant_color
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
    select item.product_id, item.quantity, item.variant_size, item.variant_color
    from jsonb_to_recordset(p_items) as item(
      product_id text,
      quantity integer,
      variant_size text,
      variant_color text
    )
  loop
    select * into v_product from public.products where id = v_item.product_id;
    insert into public.order_items (
      order_id, product_id, product_name, image_asset, quantity, unit_price,
      line_total, variant_size, variant_color
    ) values (
      v_order_id, v_product.id, v_product.name, v_product.image_asset,
      v_item.quantity, v_product.price, v_product.price * v_item.quantity,
      v_item.variant_size, v_item.variant_color
    );
  end loop;

  return query select v_order_id, v_display_id, v_total, v_expires_at, v_snapshot;
end;
$$;
