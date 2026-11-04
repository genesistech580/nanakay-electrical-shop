-- Offline-first shop sync foundation.
-- Run this in the Supabase SQL Editor after creating the project.
-- The Flutter client must use Supabase Auth and the publishable key; never use
-- a service-role/secret key in the app.

create table if not exists public.shop_sync_events (
  id uuid primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  device_id text not null,
  entity_type text not null check (
    entity_type in ('product', 'sale', 'stock_receipt', 'repayment', 'expense')
  ),
  entity_id text not null,
  operation text not null check (operation in ('upsert', 'delete')),
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (owner_id, id)
);

create index if not exists shop_sync_events_owner_received_idx
  on public.shop_sync_events (owner_id, received_at, id);

create index if not exists shop_sync_events_owner_entity_idx
  on public.shop_sync_events (owner_id, entity_type, entity_id, occurred_at);

alter table public.shop_sync_events enable row level security;

drop policy if exists "Owners can read their shop sync events"
  on public.shop_sync_events;
create policy "Owners can read their shop sync events"
  on public.shop_sync_events for select to authenticated
  using (auth.uid() is not null and auth.uid() = owner_id);

drop policy if exists "Owners can add their shop sync events"
  on public.shop_sync_events;
create policy "Owners can add their shop sync events"
  on public.shop_sync_events for insert to authenticated
  with check (auth.uid() is not null and auth.uid() = owner_id);

-- The log is append-only from the client: no update/delete policies are
-- granted. Replaying an event with the same id is safe and can be ignored by
-- the client, preventing duplicate uploads after retries.
revoke all on public.shop_sync_events from anon, authenticated;
grant select, insert on public.shop_sync_events to authenticated;
