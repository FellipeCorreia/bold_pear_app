-- Painel administrativo da NASA: quem está em public.admins enxerga os perfis e check-ins
-- de todos os astronautas (somente leitura). Ninguém se promove a admin pelo app:
-- a tabela não tem política de escrita, então só o SQL Editor / service role grava nela.

create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;

-- Cada pessoa só consegue ver se ela mesma é admin.
create policy "own admin row select" on public.admins
  for select to authenticated using ((select auth.uid()) = user_id);
revoke insert, update, delete, truncate on table public.admins from anon, authenticated;

-- security definer: consulta admins sem depender do RLS da própria tabela.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;
revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Leitura de todos os dados para admins (as políticas "own ..." continuam valendo para o resto).
create policy "admin profiles select" on public.profiles
  for select to authenticated using ((select public.is_admin()));
create policy "admin checkins select" on public.checkins
  for select to authenticated using ((select public.is_admin()));

-- Perfis + e-mail e último login (que ficam em auth.users, fora do alcance da API).
create or replace function public.admin_users()
returns table (
  id uuid,
  email text,
  display_name text,
  language text,
  voice_gender text,
  address_form text,
  onboarded boolean,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  is_admin boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select p.id, u.email::text, p.display_name, p.language, p.voice_gender, p.address_form,
           p.onboarded, p.created_at, u.last_sign_in_at,
           exists (select 1 from public.admins a where a.user_id = p.id)
    from public.profiles p
    join auth.users u on u.id = p.id
    order by p.created_at;
end; $$;
revoke execute on function public.admin_users() from public, anon;
grant execute on function public.admin_users() to authenticated;
