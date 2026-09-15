drop policy if exists "scanlab public profiles readable" on public.scanlab_profiles;
revoke select on public.scanlab_profiles from anon;
create policy "scanlab own profile readable" on public.scanlab_profiles
for select to authenticated using ((select auth.uid()) = id);
