-- D2-018 transactional two-user production-contract E2E.
-- Safe to run against a linked database: all fixture writes are rolled back.

begin;

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'::uuid),
  ('22222222-2222-4222-8222-222222222222'::uuid);

insert into public.scanlab_scans(
  id, owner_id, title, caption, visibility, status, moderation_status,
  asset_path, public_place_confirmed, privacy_confirmed, rights_confirmed,
  content_confirmed, published_at
) values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'D2 E2E A', '', 'public', 'published', 'approved',
    '11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/scene.spz',
    false, true, true, true, now()
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '22222222-2222-4222-8222-222222222222',
    'D2 E2E B', '', 'public', 'published', 'approved',
    '22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/scene.spz',
    false, true, true, true, now()
  );

create or replace function pg_temp.try_like(p_scan uuid, p_user uuid)
returns boolean language plpgsql as $$
begin
  insert into public.scanlab_likes(scan_id, user_id) values (p_scan, p_user);
  return true;
exception when others then
  return false;
end
$$;

create or replace function pg_temp.try_report(p_scan uuid, p_user uuid)
returns boolean language plpgsql as $$
begin
  insert into public.scanlab_reports(scan_id, reporter_id, reason, details)
  values (p_scan, p_user, 'other', 'd2 e2e');
  return true;
exception when others then
  return false;
end
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

insert into public.scanlab_blocks(blocker_id, blocked_id)
values ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222');

do $$
begin
  if scanlab_private.is_public_scan('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') then
    raise exception 'A still sees B after block';
  end if;
  if scanlab_private.is_reportable_scan('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') then
    raise exception 'A can report B after block';
  end if;
  if pg_temp.try_like('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111') then
    raise exception 'A can like B after block';
  end if;
  if pg_temp.try_report('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111') then
    raise exception 'A can insert report for B after block';
  end if;
end
$$;

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

do $$
begin
  if scanlab_private.is_public_scan('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') then
    raise exception 'B still sees A after being blocked';
  end if;
  if scanlab_private.is_reportable_scan('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') then
    raise exception 'B can report A after being blocked';
  end if;
  if pg_temp.try_like('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '22222222-2222-4222-8222-222222222222') then
    raise exception 'B can like A after being blocked';
  end if;
  if pg_temp.try_report('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '22222222-2222-4222-8222-222222222222') then
    raise exception 'B can insert report for A after being blocked';
  end if;
end
$$;

select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

delete from public.scanlab_blocks
where blocker_id = '11111111-1111-4111-8111-111111111111'
  and blocked_id = '22222222-2222-4222-8222-222222222222';

do $$
begin
  if not scanlab_private.is_public_scan('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') then
    raise exception 'A cannot see B after unblock';
  end if;
  if not pg_temp.try_like('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111') then
    raise exception 'A cannot like B after unblock';
  end if;
end
$$;

reset role;
select 'D2-018 transactional two-user E2E PASS' as result;
rollback;
