alter table public.orders
  add column shipping_latitude double precision,
  add column shipping_longitude double precision,
  add constraint orders_shipping_coordinates_check check (
    (shipping_latitude is null and shipping_longitude is null)
    or (
      shipping_latitude is not null
      and shipping_longitude is not null
      and shipping_latitude between -90 and 90
      and shipping_longitude between -180 and 180
    )
  );

create or replace function public.anonymize_orders_before_user_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.orders
    where user_id = old.id
      and status not in ('completed', 'cancelled')
  ) then
    raise exception using
      errcode = '23514',
      message = 'Akun masih memiliki pesanan yang belum selesai';
  end if;

  update public.orders
  set user_id = null,
      shipping_address = '',
      shipping_latitude = null,
      shipping_longitude = null,
      snap_token = null,
      snap_redirect_url = null,
      tracking_number = null,
      pickup_code = null,
      updated_at = now()
  where user_id = old.id;

  return old;
end;
$$;
