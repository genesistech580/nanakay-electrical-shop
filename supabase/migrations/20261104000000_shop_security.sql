-- Shop Owner Password / Access Gate Security.
-- Run this in the Supabase SQL Editor.

create table if not exists public.shop_security (
  id integer primary key default 1 check (id = 1),
  pin_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shop_security enable row level security;
revoke all on public.shop_security from anon, authenticated;
grant select, insert, update on public.shop_security to anon, authenticated;

drop policy if exists "Anyone can read shop security" on public.shop_security;
create policy "Anyone can read shop security"
  on public.shop_security for select to anon, authenticated
  using (true);

drop policy if exists "Anyone can insert shop security" on public.shop_security;
create policy "Anyone can insert shop security"
  on public.shop_security for insert to anon, authenticated
  with check (true);

drop policy if exists "Anyone can update shop security" on public.shop_security;
create policy "Anyone can update shop security"
  on public.shop_security for update to anon, authenticated
  using (true);
