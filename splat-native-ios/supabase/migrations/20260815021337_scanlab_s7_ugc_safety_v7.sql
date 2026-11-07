alter table public.scanlab_scans add column content_confirmed boolean not null default false;
alter table public.scanlab_scans add constraint scanlab_shared_requires_content_confirmation check (
  visibility not in ('public','unlisted') or status <> 'published' or content_confirmed
);
grant insert (content_confirmed) on public.scanlab_scans to authenticated;
grant update (content_confirmed) on public.scanlab_scans to authenticated;

create table public.scanlab_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint scanlab_no_self_block check (blocker_id <> blocked_id)
);
create index scanlab_blocks_blocked_idx on public.scanlab_blocks (blocked_id);
alter table public.scanlab_blocks enable row level security;
revoke all on public.scanlab_blocks from anon, authenticated;
grant select, insert, delete on public.scanlab_blocks to authenticated;
create policy "scanlab own blocks readable" on public.scanlab_blocks
for select to authenticated using ((select auth.uid()) = blocker_id);
create policy "scanlab block as self" on public.scanlab_blocks
for insert to authenticated with check ((select auth.uid()) = blocker_id and blocker_id <> blocked_id);
create policy "scanlab unblock as self" on public.scanlab_blocks
for delete to authenticated using ((select auth.uid()) = blocker_id);

create or replace function scanlab_private.reject_objectionable_text()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  normalized text;
begin
  normalized := lower(coalesce(new.title,'') || ' ' || coalesce(new.caption,''));
  if normalized ~ '(child[ -]?porn|child sexual|rape|pornographic|bestiality|児童ポルノ|児童性的|レイプ|強姦|殺害予告|殺すぞ)' then
    raise exception 'objectionable content text rejected';
  end if;
  return new;
end;
$$;
create trigger scanlab_scan_text_guard
before insert or update of title, caption on public.scanlab_scans
for each row execute function scanlab_private.reject_objectionable_text();

create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  recent_count integer;
begin
  if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published') then
    if new.visibility in ('public','unlisted') and not new.content_confirmed then
      raise exception 'shared scan requires content confirmation';
    end if;
    if new.visibility='public' and (new.latitude is null or new.longitude is null or not new.public_place_confirmed or not new.privacy_confirmed or not new.rights_confirmed) then
      raise exception 'public scan requires location and safety attestations';
    end if;
    if new.visibility in ('public','unlisted') then
      select count(*) into recent_count
      from public.scanlab_scans
      where owner_id=new.owner_id and status='published' and visibility in ('public','unlisted')
        and published_at > now() - interval '1 hour';
      if recent_count >= 10 then
        raise exception 'publish rate limit exceeded';
      end if;
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;
  if new.status <> 'published' then
    new.published_at := null;
  end if;
  return new;
end;
$$;

create or replace function scanlab_private.auto_hide_reported_scan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.scanlab_scans
     set status='hidden', moderation_status='pending', updated_at=now()
   where id=new.scan_id and status='published';
  return new;
end;
$$;
