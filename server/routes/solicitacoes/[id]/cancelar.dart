import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';

/// `POST /solicitacoes/{id}/cancelar`: o solicitante cancela enquanto
/// Pendente (RF 3.3.4). Sem corpo.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    throw const ApiException.methodNotAllowed();
  }
  final requestId = pathId(id, 'Solicitação não encontrada.');
  final me = context.read<UserModel>();
  checkProfile(me, {UserProfile.padrao}, 'cancelar solicitações');

  final updated = await context.read<FrotaService>().cancelRequest(
    me,
    requestId,
  );
  return Response.json(body: updated.toJson());
}
