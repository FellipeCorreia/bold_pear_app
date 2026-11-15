-- Bold Pear: perfis e check-ins (PHQ-9 + GAD-7). Já aplicado no projeto omhfegwzorvrpscdftvg.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  language text not null default 'pt' check (language in ('pt','en','de','fr','ja')),
  voice_gender text not null default 'f' check (voice_gender in ('f','m')),
  address_form text not null default 'm' check (address_form in ('f','m')),
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  language text not null check (language in ('pt','en','de','fr','ja')),
  phq_items smallint[] not null check (array_length(phq_items,1) = 9),
  phq_total smallint not null check (phq_total between 0 and 27),
  phq_difficulty smallint check (phq_difficulty between 0 and 3),
  gad_items smallint[] not null check (array_length(gad_items,1) = 7),
  gad_total smallint not null check (gad_total between 0 and 21),
  item9_positive boolean not null default false
);
create index checkins_user_created_idx on public.checkins (user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.checkins enable row level security;

create policy "own profile select" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "own profile insert" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "own profile update" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "own checkins select" on public.checkins for select to authenticated using ((select auth.uid()) = user_id);
create policy "own checkins insert" on public.checkins for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own checkins delete" on public.checkins for delete to authenticated using ((select auth.uid()) = user_id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)));
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

revoke execute on function public.handle_new_user() from public, anon, authenticated;
