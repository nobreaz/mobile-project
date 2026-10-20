import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';

/// `GET /solicitacoes/{id}/veiculos`: veículos elegíveis para aprovar esta
/// solicitação (RN 4.1): fora de manutenção/inativos, com lugares
/// suficientes e livres no período; menor quilometragem primeiro.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    throw const ApiException.methodNotAllowed();
  }
  final requestId = pathId(id, 'Solicitação não encontrada.');
  checkProfile(context.read<UserModel>(), {
    UserProfile.aprovador,
  }, 'ver os veículos elegíveis');

  final vehicles = await context.read<FrotaService>().eligibleVehicles(
    requestId,
  );
  return Response.json(body: [for (final v in vehicles) v.toJson()]);
}
