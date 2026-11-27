create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'parent' check (role in ('owner','parent')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);
create table public.children (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  school_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id,id)
);
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  child_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  title text not null default '園プリント',
  image_path text not null,
  ocr_text text not null default '',
  ai_status text not null default 'pending' check (ai_status in ('pending','processing','complete','failed','not_requested')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id,image_path),
  unique (household_id,id),
  constraint documents_child_same_household_fk foreign key (household_id,child_id)
    references public.children(household_id,id) on delete set null (child_id)
);
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  document_id uuid not null,
  child_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  title text not null check (char_length(title) between 1 and 500),
  category text not null check (category in ('submission','event','item','purchase','response','other')),
  due_date date,
  raw_date_text text,
  source_excerpt text not null default '',
  state text not null default 'review' check (state in ('review','todo','in_progress','completed','confirmed')),
  assignee_user_id uuid references auth.users(id) on delete set null,
  ai_confidence text not null default 'unrated' check (ai_confidence in ('unrated','low','medium','high')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tasks_document_same_household_fk foreign key (household_id,document_id)
    references public.documents(household_id,id) on delete cascade,
  constraint tasks_child_same_household_fk foreign key (household_id,child_id)
    references public.children(household_id,id) on delete set null (child_id)
);
create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  token_hash bytea not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.ai_extraction_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  document_id uuid references public.documents(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  model text not null,
  input_tokens integer,
  output_tokens integer,
  status text not null check (status in ('success','failed')),
  created_at timestamptz not null default now()
);

create or replace function private.is_household_member(p_household_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.household_members hm
    where hm.household_id=p_household_id and hm.user_id=auth.uid());
$$;
create or replace function private.can_manage_household(p_household_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.household_members hm
    where hm.household_id=p_household_id and hm.user_id=auth.uid()
      and hm.role in ('owner','parent'));
$$;
create or replace function public.create_household(p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_name is null or char_length(trim(p_name)) not between 1 and 80 then
    raise exception 'household name must be 1-80 characters';
  end if;
  insert into public.households(name,created_by) values(trim(p_name),auth.uid()) returning id into new_id;
  insert into public.household_members(household_id,user_id,role) values(new_id,auth.uid(),'owner');
  return new_id;
end;
$$;
create or replace function public.create_household_invite(p_household_id uuid,p_token text)
returns timestamptz language plpgsql security definer set search_path = ''
as $$
declare expiry timestamptz := now()+interval '7 days';
begin
  if auth.uid() is null or not private.can_manage_household(p_household_id) then raise exception 'not authorized'; end if;
  if p_token is null or char_length(p_token)<32 then raise exception 'invalid token'; end if;
  insert into public.household_invites(household_id,token_hash,created_by,expires_at)
  values(p_household_id,extensions.digest(convert_to(p_token,'UTF8'),'sha256'),auth.uid(),expiry);
  return expiry;
end;
$$;
create or replace function public.accept_household_invite(p_token text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare invite_row public.household_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_token is null or char_length(p_token)<32 then raise exception 'invalid invite'; end if;
  select * into invite_row from public.household_invites
  where token_hash=extensions.digest(convert_to(p_token,'UTF8'),'sha256')
    and used_at is null and expires_at>now() for update;
  if not found then raise exception 'invite is invalid or expired'; end if;
  update public.household_invites set used_at=now() where id=invite_row.id;
  insert into public.household_members(household_id,user_id,role)
  values(invite_row.household_id,auth.uid(),'parent') on conflict(household_id,user_id) do nothing;
  return invite_row.household_id;
end;
$$;
create or replace function public.guard_household_record_owner()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if tg_op='INSERT' and new.created_by is distinct from auth.uid() then
    raise exception 'created_by must match authenticated user';
  elsif tg_op='UPDATE' then
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at=now(); return new; end; $$;

create trigger documents_guard_owner before insert or update on public.documents
for each row execute function public.guard_household_record_owner();
create trigger tasks_guard_owner before insert or update on public.tasks
for each row execute function public.guard_household_record_owner();
create trigger children_touch_updated_at before update on public.children
for each row execute function public.touch_updated_at();
create trigger documents_touch_updated_at before update on public.documents
for each row execute function public.touch_updated_at();
create trigger tasks_touch_updated_at before update on public.tasks
for each row execute function public.touch_updated_at();

revoke all on schema private from public,anon;
grant usage on schema private to authenticated;
revoke all on function private.is_household_member(uuid) from public,anon;
revoke all on function private.can_manage_household(uuid) from public,anon;
grant execute on function private.is_household_member(uuid) to authenticated;
grant execute on function private.can_manage_household(uuid) to authenticated;
revoke all on function public.create_household(text) from public,anon;
revoke all on function public.create_household_invite(uuid,text) from public,anon;
revoke all on function public.accept_household_invite(text) from public,anon;
grant execute on function public.create_household(text) to authenticated;
grant execute on function public.create_household_invite(uuid,text) to authenticated;
grant execute on function public.accept_household_invite(text) to authenticated;

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.children enable row level security;
alter table public.documents enable row level security;
alter table public.tasks enable row level security;
alter table public.household_invites enable row level security;
alter table public.ai_extraction_logs enable row level security;

create policy "members can read households" on public.households
for select to authenticated using(private.is_household_member(id));
create policy "members can update household" on public.households
for update to authenticated using(private.can_manage_household(id)) with check(private.can_manage_household(id));
create policy "members can read household members" on public.household_members
for select to authenticated using(private.is_household_member(household_id));
create policy "members manage children" on public.children
for all to authenticated using(private.is_household_member(household_id))
with check(private.is_household_member(household_id));
create policy "members manage documents" on public.documents
for all to authenticated using(private.is_household_member(household_id))
with check(private.is_household_member(household_id));
create policy "members manage tasks" on public.tasks
for all to authenticated using(private.is_household_member(household_id))
with check(private.is_household_member(household_id));
create policy "deny direct invite table access" on public.household_invites
for all to anon,authenticated using(false) with check(false);
create policy "users read own ai logs" on public.ai_extraction_logs
for select to authenticated using(user_id=(select auth.uid()) and private.is_household_member(household_id));
create policy "users can write own ai usage logs" on public.ai_extraction_logs
for insert to authenticated with check(user_id=(select auth.uid()) and private.is_household_member(household_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('enprint-documents','enprint-documents',false,10485760,array['image/jpeg','image/png','image/heic','image/webp'])
on conflict(id) do nothing;
create policy "household members read print images" on storage.objects
for select to authenticated using(bucket_id='enprint-documents' and private.is_household_member(((storage.foldername(name))[1])::uuid));
create policy "household members upload print images" on storage.objects
for insert to authenticated with check(bucket_id='enprint-documents' and private.is_household_member(((storage.foldername(name))[1])::uuid));
create policy "household members update print images" on storage.objects
for update to authenticated using(bucket_id='enprint-documents' and private.is_household_member(((storage.foldername(name))[1])::uuid))
with check(bucket_id='enprint-documents' and private.is_household_member(((storage.foldername(name))[1])::uuid));
create policy "household members delete print images" on storage.objects
for delete to authenticated using(bucket_id='enprint-documents' and private.is_household_member(((storage.foldername(name))[1])::uuid));

create index household_members_user_idx on public.household_members(user_id);
create index children_household_idx on public.children(household_id);
create index households_created_by_idx on public.households(created_by);
create index documents_household_created_idx on public.documents(household_id,created_at desc);
create index documents_child_id_idx on public.documents(child_id);
create index documents_created_by_idx on public.documents(created_by);
create index documents_household_child_idx on public.documents(household_id,child_id);
create index documents_household_id_idx on public.documents(household_id);
create index tasks_household_due_idx on public.tasks(household_id,due_date);
create index tasks_document_idx on public.tasks(document_id);
create index tasks_assignee_user_id_idx on public.tasks(assignee_user_id);
create index tasks_child_id_idx on public.tasks(child_id);
create index tasks_created_by_idx on public.tasks(created_by);
create index tasks_household_child_idx on public.tasks(household_id,child_id);
create index tasks_household_document_idx on public.tasks(household_id,document_id);
create index household_invites_created_by_idx on public.household_invites(created_by);
create index household_invites_household_idx on public.household_invites(household_id);
create index ai_extraction_logs_household_idx on public.ai_extraction_logs(household_id,created_at desc);
create index ai_extraction_logs_document_idx on public.ai_extraction_logs(document_id);
create index ai_extraction_logs_user_idx on public.ai_extraction_logs(user_id);
