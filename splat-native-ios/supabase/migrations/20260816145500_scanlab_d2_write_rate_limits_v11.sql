create table scanlab_private.rate_limit_buckets (
  actor_id uuid not null references auth.users(id) on delete cascade,
  action_key text not null,
  tokens numeric not null,
  last_refill_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (actor_id, action_key),
  constraint scanlab_rate_limit_action_check check (
    action_key in ('publish_shared', 'report', 'block_mutation')
  ),
  constraint scanlab_rate_limit_tokens_check check (tokens >= 0)
);

alter table scanlab_private.rate_limit_buckets enable row level security;
revoke all on table scanlab_private.rate_limit_buckets from public, anon, authenticated;

create or replace function scanlab_private.consume_rate_limit(
  actor uuid,
  rate_key text,
  max_hits integer,
  window_size interval
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  now_ts timestamptz := pg_catalog.clock_timestamp();
  current_tokens numeric;
  previous_refill timestamptz;
  window_seconds numeric;
  elapsed_seconds numeric;
  available_tokens numeric;
begin
  if actor is null then
    raise exception 'rate limit actor required';
  end if;
  if rate_key not in ('publish_shared', 'report', 'block_mutation') then
    raise exception 'unsupported rate limit key';
  end if;
  if max_hits <= 0 then
    raise exception 'invalid rate limit capacity';
  end if;

  window_seconds := pg_catalog.date_part('epoch', window_size)::numeric;
  if window_seconds <= 0 then
    raise exception 'invalid rate limit window';
  end if;

  -- Serialize all mutations for the same user/action before reading the bucket.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(actor::text || ':' || rate_key, 0)
  );

  select b.tokens, b.last_refill_at
    into current_tokens, previous_refill
  from scanlab_private.rate_limit_buckets b
  where b.actor_id = actor
    and b.action_key = rate_key
  for update;

  if not found then
    insert into scanlab_private.rate_limit_buckets (
      actor_id,
      action_key,
      tokens,
      last_refill_at,
      updated_at
    ) values (
      actor,
      rate_key,
      (max_hits - 1)::numeric,
      now_ts,
      now_ts
    );
    return;
  end if;

  elapsed_seconds := greatest(
    0::numeric,
    pg_catalog.date_part('epoch', now_ts - previous_refill)::numeric
  );

  available_tokens := least(
    max_hits::numeric,
    current_tokens + (elapsed_seconds * max_hits::numeric / window_seconds)
  );

  if available_tokens < 1 then
    raise exception 'rate limit exceeded: %', rate_key;
  end if;

  update scanlab_private.rate_limit_buckets
     set tokens = available_tokens - 1,
         last_refill_at = now_ts,
         updated_at = now_ts
   where actor_id = actor
     and action_key = rate_key;
end;
$$;

revoke all on function scanlab_private.consume_rate_limit(uuid, text, integer, interval)
  from public, anon, authenticated;

create or replace function scanlab_private.enforce_report_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform scanlab_private.consume_rate_limit(
    new.reporter_id,
    'report',
    20,
    interval '1 hour'
  );
  return new;
end;
$$;

revoke all on function scanlab_private.enforce_report_rate_limit()
  from public, anon, authenticated;

drop trigger if exists scanlab_reports_rate_limit on public.scanlab_reports;
create trigger scanlab_reports_rate_limit
before insert on public.scanlab_reports
for each row execute function scanlab_private.enforce_report_rate_limit();

create or replace function scanlab_private.enforce_block_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid;
begin
  actor := case when tg_op = 'DELETE' then old.blocker_id else new.blocker_id end;

  perform scanlab_private.consume_rate_limit(
    actor,
    'block_mutation',
    60,
    interval '1 hour'
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function scanlab_private.enforce_block_rate_limit()
  from public, anon, authenticated;

drop trigger if exists scanlab_blocks_rate_limit on public.scanlab_blocks;
create trigger scanlab_blocks_rate_limit
before insert or delete on public.scanlab_blocks
for each row execute function scanlab_private.enforce_block_rate_limit();

create or replace function scanlab_private.publish_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entering_shared boolean := false;
begin
  if new.status = 'published' and new.visibility in ('public', 'unlisted') then
    if tg_op = 'INSERT' then
      entering_shared := true;
    else
      entering_shared :=
        old.status is distinct from 'published'
        or old.visibility not in ('public', 'unlisted');
    end if;

    if not new.content_confirmed then
      raise exception 'shared scan requires content confirmation';
    end if;

    if new.visibility = 'public'
       and (
         new.latitude is null
         or new.longitude is null
         or not new.public_place_confirmed
         or not new.privacy_confirmed
         or not new.rights_confirmed
       ) then
      raise exception 'public scan requires location and safety attestations';
    end if;
  end if;

  if entering_shared then
    perform scanlab_private.consume_rate_limit(
      new.owner_id,
      'publish_shared',
      10,
      interval '1 hour'
    );
    new.published_at := pg_catalog.now();
  elsif new.status = 'published'
        and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    new.published_at := coalesce(new.published_at, pg_catalog.now());
  end if;

  if new.status <> 'published' then
    new.published_at := null;
  end if;

  return new;
end;
$$;

revoke all on function scanlab_private.publish_guard()
  from public, anon, authenticated;
