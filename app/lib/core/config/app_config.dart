/// Configuração do app, passada na hora de rodar:
///   flutter run --dart-define-from-file=env/dev.json
/// (o F5 do VS Code já faz isso). Modelo em `env/example.json`.
///
/// Nenhum segredo aqui: a chave publishable é pública por definição.
/// A chave secreta do Supabase existe só no servidor.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Endereço da API (Dart Frog). Ex.: http://localhost:8080 (web/desktop)
  /// ou http://10.0.2.2:8080 (emulador Android acessando o PC).
  static const apiUrl = String.fromEnvironment('API_URL');

  static bool get isComplete =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      apiUrl.isNotEmpty;
}
