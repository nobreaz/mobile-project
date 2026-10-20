import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/request_input.dart';

/// `POST /solicitacoes/{id}/devolucao` `{"mileage": 42660, "notes": "..."}`:
/// check-in do veículo pelo solicitante (RF 3.3.6). A km não pode ser menor
/// que a de saída (RN 4.8). `notes` é opcional.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    throw const ApiException.methodNotAllowed();
  }
  final requestId = pathId(id, 'Solicitação não encontrada.');
  final me = context.read<UserModel>();
  checkProfile(me, {UserProfile.padrao}, 'registrar a devolução');

  final input = parseMileage(await readJsonObject(context));
  final updated = await context.read<FrotaService>().checkIn(
    me,
    requestId,
    mileage: input.mileage,
    notes: input.notes,
  );
  return Response.json(body: updated.toJson());
}
