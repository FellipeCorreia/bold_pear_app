/// Supabase do projeto Bold Pear. A chave publishable é pública por design
/// (o acesso aos dados é protegido por RLS). Pode ser sobrescrita com
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://omhfegwzorvrpscdftvg.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_XmV02cV9jHK22JtykVhJCg_4m0Am82B',
  );
}
