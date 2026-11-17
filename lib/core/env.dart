/// Credenciales de Supabase inyectadas al compilar:
///
///   flutter run --dart-define-from-file=env.json
///
/// env.json (NO subirlo a git):
///   { "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "eyJ..." }
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Faltan SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Ejecuta con --dart-define-from-file=env.json',
      );
    }
  }
}
