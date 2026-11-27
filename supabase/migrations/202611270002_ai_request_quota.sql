create table public.ai_monthly_limits (
  month_start date primary key,
  request_count integer not null default 0 check (request_count between 0 and 1000),
  updated_at timestamptz not null default now()
);
alter table public.ai_monthly_limits enable row level security;
create policy "deny direct monthly AI quota access" on public.ai_monthly_limits
for all to anon,authenticated using(false) with check(false);

create or replace function public.reserve_ai_request(p_household_id uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare current_month date := date_trunc('month',now())::date; reserved_count integer;
begin
  if auth.uid() is null or not private.is_household_member(p_household_id) then
    raise exception 'not authorized';
  end if;
  insert into public.ai_monthly_limits(month_start,request_count)
  values(current_month,1)
  on conflict(month_start) do update
    set request_count=public.ai_monthly_limits.request_count+1, updated_at=now()
    where public.ai_monthly_limits.request_count<1000
  returning request_count into reserved_count;
  if reserved_count is null then raise exception 'monthly AI request limit reached'; end if;
  return reserved_count;
end;
$$;
revoke all on function public.reserve_ai_request(uuid) from public,anon;
grant execute on function public.reserve_ai_request(uuid) to authenticated;
