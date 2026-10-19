import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';

/// `GET /health`: verifica se a API está no ar.
///
/// Devolve também os status de solicitação vindos do `frota_core`,
/// o mesmo pacote usado pelo app: prova de que o domínio é compartilhado.
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  return Response.json(
    body: {
      'status': 'ok',
      'statusSolicitacao': [
        for (final s in RequestStatus.values) {'id': s.name, 'label': s.label},
      ],
    },
  );
}
