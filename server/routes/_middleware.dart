import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/services.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';

/// Vale para todas as rotas: CORS, tratamento de erros e dependências.
/// (O último `.use` é o mais externo: o CORS roda primeiro.)
Handler middleware(Handler handler) {
  return handler
      .use(provider<UsuariosRepository>((_) => Services().usuarios))
      .use(provider<SupabaseAuth>((_) => Services().auth))
      .use(errorHandler())
      .use(cors());
}
