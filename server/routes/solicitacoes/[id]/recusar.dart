import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/request_input.dart';

/// `POST /solicitacoes/{id}/recusar` `{"justification": "..."}`:
/// recusa com justificativa obrigatória (RF 3.4.3, RN 4.7).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    throw const ApiException.methodNotAllowed();
  }
  final requestId = pathId(id, 'Solicitação não encontrada.');
  final me = context.read<UserModel>();
  checkProfile(me, {UserProfile.aprovador}, 'recusar solicitações');

  final justification = parseRejection(await readJsonObject(context));
  final updated = await context.read<FrotaService>().reject(
    me,
    requestId,
    justification,
  );
  return Response.json(body: updated.toJson());
}
