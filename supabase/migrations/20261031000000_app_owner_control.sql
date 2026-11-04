-- Owner-only application controls and private update metadata.
-- Apply this migration in the Supabase SQL Editor.
-- After creating/signing into the owner's Supabase account, run the seed
-- statement in README.md with that account's email address.

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;
grant select on public.app_admins to authenticated;

drop policy if exists "Admins can identify their own role" on public.app_admins;
create policy "Admins can identify their own role"
  on public.app_admins for select to authenticated
  using (auth.uid() = user_id);

create table if not exists public.app_control (
  id integer primary key check (id = 1),
  app_enabled boolean not null default true,
  maintenance_message text not null default '',
  latest_version text not null default '1.0.0',
  latest_build integer not null default 1 check (latest_build > 0),
  minimum_build integer not null default 1 check (minimum_build > 0),
  android_apk_url text not null default '',
  release_notes text not null default '',
  updated_at timestamptz not null default now(),
  check (minimum_build <= latest_build)
);

insert into public.app_control (id) values (1)
on conflict (id) do nothing;

alter table public.app_control enable row level security;
revoke all on public.app_control from anon, authenticated;
grant select on public.app_control to anon, authenticated;
grant update on public.app_control to authenticated;

drop policy if exists "App users can read public release controls" on public.app_control;
create policy "App users can read public release controls"
  on public.app_control for select to anon, authenticated
  using (true);

drop policy if exists "Approved admins can update app controls" on public.app_control;
create policy "Approved admins can update app controls"
  on public.app_control for update to authenticated
  using (
    exists (
      select 1 from public.app_admins a where a.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.app_admins a where a.user_id = auth.uid()
    )
  );