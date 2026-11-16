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

  /// Onde o app baixa a voz neural (Supertonic 3 int8 do sherpa-onnx) na primeira abertura.
  /// Revisão fixada: os arquivos nunca mudam por baixo do app (o SHA-256 de cada um é conferido).
  /// Para hospedar em outro lugar: --dart-define=VOICE_MODEL_URL=https://.../pasta
  static const voiceModelUrl = String.fromEnvironment(
    'VOICE_MODEL_URL',
    defaultValue: 'https://huggingface.co/csukuangfj2/sherpa-onnx-supertonic-3-tts-int8-2026-05-11'
        '/resolve/cca5a0e6c96e1d2c720986bf7e75fcc81dee3ae4',
  );
}
