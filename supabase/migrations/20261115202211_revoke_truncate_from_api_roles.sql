-- TRUNCATE não passa pelo RLS: os papéis da API (anon/authenticated) não precisam dele.
revoke truncate on table public.profiles, public.checkins from anon, authenticated;
-- Vale também para tabelas criadas no futuro no schema public.
alter default privileges in schema public revoke truncate on tables from anon, authenticated;
