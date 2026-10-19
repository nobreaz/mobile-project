import 'package:dotenv/dotenv.dart';

/// Configuração da API, lida das variáveis de ambiente.
///
/// Em desenvolvimento, os valores vêm do arquivo `server/.env`
/// (copie o `.env.example`). Em produção, das variáveis do servidor.
/// Nenhum segredo fica no código nem no repositório.
class Config {
  const Config({
    required this.databaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.supabaseSecretKey,
  });

  factory Config.fromEnvironment() {
    final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();

    String required(String key) {
      final value = env[key];
      if (value == null || value.trim().isEmpty) {
        throw StateError(
          'Variável de ambiente $key não definida. '
          'Copie server/.env.example para server/.env e preencha.',
        );
      }
      return value.trim();
    }

    return Config(
      databaseUrl: required('DATABASE_URL'),
      supabaseUrl: Uri.parse(required('SUPABASE_URL')),
      supabasePublishableKey: required('SUPABASE_PUBLISHABLE_KEY'),
      supabaseSecretKey: required('SUPABASE_SECRET_KEY'),
    );
  }

  /// Conexão direta com o PostgreSQL do Supabase (pooler, modo session).
  final String databaseUrl;

  /// Ex.: https://abcdefgh.supabase.co
  final Uri supabaseUrl;

  /// Chave pública (`sb_publishable_...`), a mesma usada no app.
  final String supabasePublishableKey;

  /// Chave secreta (`sb_secret_...`). Só no servidor: cria e bloqueia logins.
  final String supabaseSecretKey;
}
