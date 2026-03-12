-- Run this in Supabase Dashboard → SQL Editor → New query, then Run.
-- Creates tables and RLS for checklist items and per-user completion.

-- Global checklist items (same for all users)
create table if not exists public.checklist_items (
  id text primary key,
  checklist_id text not null default 'global',
  title text not null,
  url text,
  sort_order int not null default 0
);

-- Per-user completion (one row per user + checklist + item)
create table if not exists public.user_checklist (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  checklist_id text not null,
  item_id text not null,
  is_complete boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id, checklist_id, item_id)
);

-- RLS: anyone signed in can read checklist items
alter table public.checklist_items enable row level security;
create policy "Allow read for authenticated"
  on public.checklist_items for select
  to authenticated
  using (true);

-- RLS: users can only read/write their own user_checklist rows
alter table public.user_checklist enable row level security;
create policy "Users can read own rows"
  on public.user_checklist for select
  to authenticated
  using (auth.uid() = user_id);
create policy "Users can insert own rows"
  on public.user_checklist for insert
  to authenticated
  with check (auth.uid() = user_id);
create policy "Users can update own rows"
  on public.user_checklist for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Optional: insert a sample item so the app shows something
-- insert into public.checklist_items (id, checklist_id, title, url, sort_order)
-- values ('sample-1', 'global', 'Sample item', 'https://example.com', 0);
