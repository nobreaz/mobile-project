import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/request_input.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';

/// `/solicitacoes/{id}`
/// - GET: detalhe. Padrão só vê as próprias; Aprovador e Administrador, todas.
/// - PATCH: o solicitante altera antes da retirada (RF 3.3.3). Só os campos
///   enviados mudam. Se estava aprovada e mudaram datas, período ou
///   passageiros, volta com `status: "pendente"` (precisa de nova aprovação).
Future<Response> onRequest(RequestContext context, String id) async {
  final requestId = pathId(id, 'Solicitação não encontrada.');
  final me = context.read<UserModel>();

  switch (context.request.method) {
    case HttpMethod.get:
      final request = await context.read<SolicitacoesRepository>().findById(
        requestId,
      );
      // Para o Padrão, a de outra pessoa "não existe" (não revela nada).
      if (request == null ||
          (me.profile == UserProfile.padrao && request.requesterId != me.id)) {
        throw const ApiException.notFound('Solicitação não encontrada.');
      }
      return Response.json(body: request.toJson());

    case HttpMethod.patch:
      checkProfile(me, {UserProfile.padrao}, 'alterar solicitações');
      final fields = RequestFields.fromJson(
        await readJsonObject(context),
        partial: true,
      );
      final updated = await context.read<FrotaService>().updateRequest(
        me,
        requestId,
        fields,
      );
      return Response.json(body: updated.toJson());

    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}
