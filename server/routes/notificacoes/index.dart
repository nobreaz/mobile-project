import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/notificacoes_repository.dart';

/// `GET /notificacoes`: as notificações do usuário logado (RF 3.3.7),
/// mais recentes primeiro. Cada um só vê as suas.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    throw const ApiException.methodNotAllowed();
  }
  final me = context.read<UserModel>();
  final items = await context.read<NotificacoesRepository>().listFor(me.id);
  return Response.json(body: [for (final n in items) n.toJson()]);
}
