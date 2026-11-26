alter table public.orders
  alter column user_id drop not null;

alter table public.orders
  drop constraint if exists orders_user_id_fkey;

alter table public.orders
  add constraint orders_user_id_fkey
  foreign key (user_id) references auth.users (id) on delete set null;

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
      snap_token = null,
      snap_redirect_url = null,
      tracking_number = null,
      pickup_code = null,
      updated_at = now()
  where user_id = old.id;

  return old;
end;
$$;

revoke all on function public.anonymize_orders_before_user_delete()
  from public, anon, authenticated;

drop trigger if exists anonymize_orders_before_user_delete on auth.users;
create trigger anonymize_orders_before_user_delete
  before delete on auth.users
  for each row
  execute function public.anonymize_orders_before_user_delete();

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
    if v_order.user_id is distinct from p_actor_id and not p_is_admin then
      raise exception 'Tidak berwenang membatalkan pesanan ini';
    end if;
    if v_order.status = 'cancelled' then
      return;
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
    if v_order.user_id is distinct from p_actor_id then
      raise exception 'Bukan pemilik pesanan';
    end if;
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
