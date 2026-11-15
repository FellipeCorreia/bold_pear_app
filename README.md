# Bold Pear

Bem-estar mental para astronautas — NASA Space Apps Challenge 2026.
A Bold Pear, uma pera 3D, conduz em voz alta um check-in com PHQ-9 e GAD-7 nos idiomas
português, inglês, alemão, francês e japonês, e mostra a evolução num dashboard.

## Rodar

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # Android / iOS
```

Build web: `flutter build web --release --no-web-resources-cdn`

O app já aponta para o projeto Supabase **Bold Pear** (`omhfegwzorvrpscdftvg`, região sa-east-1).
Para usar outro projeto:
`--dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_...`

## Supabase

- Tabelas `profiles` e `checkins`, com RLS: cada pessoa só vê e grava os próprios dados.
- Um gatilho cria o perfil no cadastro (nome vem de `display_name`).
- SQL em `supabase/migrations/`.
- **Confirmação de e-mail:** projetos novos exigem confirmar o e-mail antes do primeiro login, e o
  SMTP padrão do Supabase envia poucos e-mails por hora. Para a demo, dá para desligar em
  Authentication → Sign In / Providers → Email → *Confirm email*, ou configurar um SMTP próprio.

## Painel NASA (admin)

Contas listadas em `public.admins` entram direto no painel `/admin` (sem pera, onboarding ou
check-in). O painel mostra os indicadores da tripulação (ativos, atrasados, em atenção, item 9,
médias de PHQ-9/GAD-7, adesão, faixas, check-ins por semana, sintomas mais marcados) e a ficha
de cada astronauta (perfil, estatísticas, alertas, evolução, itens e histórico completo).

1. Rode `supabase/migrations/20261115230000_admin_dashboard.sql` no SQL Editor.
2. Crie a conta (cadastro no app ou Authentication → Users → Add user).
3. Troque o e-mail em `supabase/grant_admin.sql` e rode no SQL Editor.

Só o banco decide quem é admin (`public.is_admin()` + RLS, somente leitura); o app não consegue
se promover.

## Fluxo

1. Boas-vindas: escolha do idioma (a pera cumprimenta), criar conta ou entrar.
2. Cadastro (nome, e-mail, senha) ou login; recuperação de senha por e-mail.
3. Primeiro acesso: a pera avisa que é só um programa e que ninguém ouve ao vivo; escolha da voz
   (feminina/masculina) e do nome; forma de tratamento em português e francês.
4. Dashboard: próximo check-in (a cada 14 dias), gráficos de PHQ-9 e GAD-7 sobre as faixas de
   gravidade, histórico e respiração guiada.
5. Check-in falado: PHQ-9 → impacto no dia a dia (se houver sintoma) → GAD-7. As perguntas são
   faladas; a tela mostra só as opções. Legendas opcionais (botão CC).
6. Resultado: faixas, aviso de segurança se o item 9 for positivo, práticas sugeridas.

A pera fica viva em todas as telas (`lib/app/shell.dart`): o mesmo HTML com three.js
(`assets/avatar/index.html`, offline) roda numa WebView no celular e num iframe na web.

## Estrutura

```
lib/
  app/            estado da sessão, rotas (go_router) e a moldura com a pera
  core/           cores (pi_cores.dart), tema, textos nos 5 idiomas, widgets
  features/
    auth/         boas-vindas, login, cadastro
    profile/      onboarding, ajustes, repositório do perfil
    checkin/      escalas, pontuação, fluxo falado, resultado, respiração
    dashboard/    evolução e histórico
    avatar/       pera 3D (WebView / iframe) e seu controlador
    voice/        voz (TTS) que move a boca da pera e as legendas
```

## Pendências antes de uso real

- Trocar os textos de GAD-7 (todos os idiomas) e PHQ-9 (DE, FR, JA) pelas traduções oficiais validadas.
- Escolher as vozes neurais por idioma e gênero e pré-gerar os áudios (hoje usa a voz do sistema).
- Ferramenta de bem-estar; não faz diagnóstico.
