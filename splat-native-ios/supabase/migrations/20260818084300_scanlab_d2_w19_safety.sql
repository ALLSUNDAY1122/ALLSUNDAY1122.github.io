-- D2-019: moderation / rate-limit / abuse resistance / failure handling

create table if not exists public.scanlab_moderation_actions (
  id bigint generated always as identity primary key,
  scan_id uuid not null references public.scanlab_scans(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('hide','restore','reject')),
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default now()
);
create index if not exists scanlab_moderation_actions_scan_idx on public.scanlab_moderation_actions (scan_id, created_at desc);
alter table public.scanlab_moderation_actions enable row level security;
revoke all on public.scanlab_moderation_actions from anon, authenticated;

create table if not exists public.scanlab_abuse_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in ('publish','report')),
  target_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists scanlab_abuse_events_actor_action_idx on public.scanlab_abuse_events (actor_id, action, created_at desc);
alter table public.scanlab_abuse_events enable row level security;
revoke all on public.scanlab_abuse_events from anon, authenticated;

create or replace function scanlab_private.enforce_abuse_limit(p_actor uuid, p_action text, p_target uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare recent_count integer; max_count integer; window_size interval;
begin
  if p_actor is null or p_actor <> (select auth.uid()) then
    raise exception using errcode='42501', message='abuse guard actor mismatch';
  end if;
  if p_action='publish' then max_count:=10; window_size:=interval '1 hour';
  elsif p_action='report' then max_count:=20; window_size:=interval '1 hour';
  else raise exception using errcode='22023', message='unsupported abuse guard action'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_actor::text || ':' || p_action, 0));
  select count(*) into recent_count from public.scanlab_abuse_events
   where actor_id=p_actor and action=p_action and created_at > now()-window_size;
  if recent_count >= max_count then
    raise exception using errcode='P0001', message='rate limit exceeded', hint='retry later';
  end if;
  insert into public.scanlab_abuse_events(actor_id,action,target_id) values(p_actor,p_action,p_target);
end; $$;
revoke all on function scanlab_private.enforce_abuse_limit(uuid,text,uuid) from public, anon, authenticated;

-- Owners must not be able to self-approve or otherwise rewrite moderation state.
-- pg_trigger_depth() permits nested server-side moderation updates such as auto-hide.
create or replace function scanlab_private.owner_moderation_state_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if pg_trigger_depth() = 1 and (select auth.uid()) = new.owner_id then
    if tg_op='INSERT' then
      if new.moderation_status <> 'pending' then
        raise exception using errcode='42501', message='owner cannot set moderation state';
      end if;
    elsif new.moderation_status is distinct from old.moderation_status then
      raise exception using errcode='42501', message='owner cannot change moderation state';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists scanlab_owner_moderation_state_guard on public.scanlab_scans;
create trigger scanlab_owner_moderation_state_guard
before insert or update of moderation_status on public.scanlab_scans
for each row execute function scanlab_private.owner_moderation_state_guard();

create or replace function scanlab_private.publish_guard()
returns trigger language plpgsql set search_path = '' as $$
declare entering_shared boolean;
begin
  entering_shared := new.status='published' and new.visibility in ('public','unlisted') and (
    tg_op='INSERT' or old.status is distinct from 'published' or old.visibility not in ('public','unlisted')
  );

  if new.status='published' then
    if new.visibility in ('public','unlisted') and not new.content_confirmed then
      raise exception using errcode='23514', message='shared scan requires content confirmation';
    end if;
    if new.visibility='public' and (new.latitude is null or new.longitude is null or not new.public_place_confirmed or not new.privacy_confirmed or not new.rights_confirmed) then
      raise exception using errcode='23514', message='public scan requires location and safety attestations';
    end if;
    if entering_shared then
      perform scanlab_private.enforce_abuse_limit(new.owner_id,'publish',new.id);
    end if;
    new.published_at:=coalesce(new.published_at,now());
  else
    new.published_at:=null;
  end if;
  return new;
end; $$;

create or replace function scanlab_private.report_abuse_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.reporter_id is null or new.reporter_id <> (select auth.uid()) then
    raise exception using errcode='42501', message='reporter mismatch';
  end if;
  perform scanlab_private.enforce_abuse_limit(new.reporter_id,'report',new.scan_id);
  return new;
end; $$;

-- The reports table is already part of the D2 base contract. Fail migration loudly if that contract regresses.
drop trigger if exists scanlab_report_abuse_guard on public.scanlab_reports;
create trigger scanlab_report_abuse_guard before insert on public.scanlab_reports
for each row execute function scanlab_private.report_abuse_guard();

create or replace function scanlab_private.auto_hide_reported_scan()
returns trigger language plpgsql security definer set search_path = '' as $$
declare affected integer;
begin
  update public.scanlab_scans set status='hidden',moderation_status='pending',updated_at=now()
   where id=new.scan_id and status='published';
  get diagnostics affected=row_count;
  if affected>0 then
    insert into public.scanlab_moderation_actions(scan_id,actor_id,action,reason)
    values(new.scan_id,new.reporter_id,'hide','user report');
  end if;
  return new;
end; $$;

create or replace function scanlab_private.prune_abuse_events()
returns integer language plpgsql security definer set search_path = '' as $$
declare deleted_count integer;
begin
  delete from public.scanlab_abuse_events where created_at < now()-interval '7 days';
  get diagnostics deleted_count=row_count;
  return deleted_count;
end; $$;
revoke all on function scanlab_private.prune_abuse_events() from public, anon, authenticated;
