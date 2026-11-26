create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users (id) on delete cascade,
  sender_id uuid references auth.users (id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists support_messages_customer_created_idx
  on public.support_messages (customer_id, created_at, id);

alter table public.support_messages enable row level security;

drop policy if exists "Customers and admins read support messages"
  on public.support_messages;
create policy "Customers and admins read support messages"
  on public.support_messages for select to authenticated
  using (
    customer_id = (select auth.uid())
    or (select public.current_user_is_admin())
  );

drop policy if exists "Customers and admins send support messages"
  on public.support_messages;
create policy "Customers and admins send support messages"
  on public.support_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and (
      (
        customer_id = (select auth.uid())
        and not (select public.current_user_is_admin())
      )
      or (
        (select public.current_user_is_admin())
        and exists (
          select 1
          from public.profiles
          where id = customer_id and role = 'customer'
        )
      )
    )
  );

revoke all on public.support_messages from anon, authenticated;
grant select, insert on public.support_messages to authenticated;

create or replace view public.support_conversations
with (security_invoker = true)
as
select distinct on (message.customer_id)
  message.customer_id,
  coalesce(nullif(btrim(profile.full_name), ''), 'Pembeli') as customer_name,
  message.sender_id,
  message.body as last_message,
  message.created_at as last_message_at
from public.support_messages as message
join public.profiles as profile on profile.id = message.customer_id
order by message.customer_id, message.created_at desc, message.id desc;

revoke all on public.support_conversations from anon, authenticated;
grant select on public.support_conversations to authenticated;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_messages'
  ) then
    alter publication supabase_realtime add table public.support_messages;
  end if;
end;
$$;
