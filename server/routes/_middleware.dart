import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/notificacoes_repository.dart';
import 'package:frota_server/src/relatorios_repository.dart';
import 'package:frota_server/src/services.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';

/// Vale para todas as rotas: CORS, tratamento de erros e dependências.
/// (O último `.use` é o mais externo: o CORS roda primeiro.)
Handler middleware(Handler handler) {
  return handler
      .use(provider<UsuariosRepository>((_) => Services().usuarios))
      .use(provider<SolicitacoesRepository>((_) => Services().solicitacoes))
      .use(provider<VeiculosRepository>((_) => Services().veiculos))
      .use(provider<NotificacoesRepository>((_) => Services().notificacoes))
      .use(provider<RelatoriosRepository>((_) => Services().relatorios))
      .use(provider<FrotaService>((_) => Services().frota))
      .use(provider<SupabaseAuth>((_) => Services().auth))
      .use(errorHandler())
      .use(cors());
}
