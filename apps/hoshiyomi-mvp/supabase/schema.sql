create extension if not exists pgcrypto;
create table if not exists public.fortune_orders(id uuid primary key default gen_random_uuid(),kind text not null check(kind in('love','compatibility','career')),inputs jsonb not null,product text not null check(product in('detail','pair')),amount_yen integer not null check(amount_yen in(480,980)),access_hash text not null check(length(access_hash)=64),checkout_session_id text unique,status text not null default 'pending' check(status in('pending','paid','refunded')),created_at timestamptz not null default now(),paid_at timestamptz);
alter table public.fortune_orders enable row level security;
revoke all on table public.fortune_orders from anon,authenticated;
create index if not exists fortune_orders_created_idx on public.fortune_orders(created_at desc);
