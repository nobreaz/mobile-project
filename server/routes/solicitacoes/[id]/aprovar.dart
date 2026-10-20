import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/request_input.dart';

/// `POST /solicitacoes/{id}/aprovar` `{"vehicleId": 3}`: aprova e aloca
/// o veículo (RF 3.4.2). O veículo precisa estar entre os elegíveis
/// (`GET /solicitacoes/{id}/veiculos`).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    throw const ApiException.methodNotAllowed();
  }
  final requestId = pathId(id, 'Solicitação não encontrada.');
  final me = context.read<UserModel>();
  checkProfile(me, {UserProfile.aprovador}, 'aprovar solicitações');

  final vehicleId = parseApproval(await readJsonObject(context));
  final updated = await context.read<FrotaService>().approve(
    me,
    requestId,
    vehicleId,
  );
  return Response.json(body: updated.toJson());
}
