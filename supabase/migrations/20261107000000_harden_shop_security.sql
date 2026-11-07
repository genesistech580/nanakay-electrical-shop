-- Run in the Supabase SQL Editor after the existing owner-control migration.
begin;

drop policy if exists "Anyone can read shop security" on public.shop_security;
drop policy if exists "Anyone can insert shop security" on public.shop_security;
drop policy if exists "Anyone can update shop security" on public.shop_security;
revoke all on public.shop_security from anon, authenticated;
grant select, insert, update on public.shop_security to authenticated;

drop policy if exists "Approved admins manage shop security" on public.shop_security;
create policy "Approved admins manage shop security"
  on public.shop_security for all to authenticated
  using (exists (select 1 from public.app_admins where user_id = auth.uid()))
  with check (exists (select 1 from public.app_admins where user_id = auth.uid()));

-- Return only a boolean, never the stored credential hash.
create or replace function public.shop_password_configured()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.shop_security where id = 1); $$;

create or replace function public.verify_shop_password(candidate_hash text)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.shop_security where id = 1 and pin_hash = candidate_hash
); $$;

revoke all on function public.shop_password_configured() from public;
revoke all on function public.verify_shop_password(text) from public;
grant execute on function public.shop_password_configured() to anon, authenticated;
grant execute on function public.verify_shop_password(text) to anon, authenticated;

commit;
