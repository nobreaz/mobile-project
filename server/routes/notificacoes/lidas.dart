import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/notificacoes_repository.dart';

/// `POST /notificacoes/lidas`: marca todas as notificações do usuário logado
/// como lidas (ao abrir a tela de notificações). Sem corpo; responde 204.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    throw const ApiException.methodNotAllowed();
  }
  final me = context.read<UserModel>();
  await context.read<NotificacoesRepository>().markAllRead(me.id);
  return Response(statusCode: HttpStatus.noContent);
}
