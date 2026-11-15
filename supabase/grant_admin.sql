-- Torna uma conta existente admin do painel NASA.
-- 1. Crie a conta normalmente (cadastro no app ou Authentication → Users → Add user).
-- 2. Troque o e-mail abaixo e rode no SQL Editor do Supabase.
insert into public.admins (user_id)
select id from auth.users where email = 'admin@exemplo.com'
on conflict (user_id) do nothing;

-- Para remover:
-- delete from public.admins where user_id = (select id from auth.users where email = 'admin@exemplo.com');
