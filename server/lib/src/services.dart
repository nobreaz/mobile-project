import 'package:frota_server/src/config.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/notificacoes_repository.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';
import 'package:postgres/postgres.dart';

/// Objetos de longa duração da API (um por processo).
///
/// Criados na primeira requisição que precisar deles, para que rotas como
/// `/health` funcionem mesmo sem o `.env` configurado.
class Services {
  /// Sempre a mesma instância (criada na primeira chamada).
  factory Services() => _instance ??= Services._(Config.fromEnvironment());

  Services._(this.config)
    : db = Pool.withUrl(config.databaseUrl),
      auth = SupabaseAuth(
        url: config.supabaseUrl,
        publishableKey: config.supabasePublishableKey,
        secretKey: config.supabaseSecretKey,
      );

  static Services? _instance;

  final Config config;

  /// Pool de conexões com o PostgreSQL do Supabase.
  final Pool<void> db;

  final SupabaseAuth auth;

  late final usuarios = UsuariosRepository(db);

  late final solicitacoes = SolicitacoesRepository(db);

  late final veiculos = VeiculosRepository(db);

  late final notificacoes = NotificacoesRepository(db);

  /// Regras de solicitações e veículos (cada operação numa transação).
  late final frota = FrotaService(db);
}
