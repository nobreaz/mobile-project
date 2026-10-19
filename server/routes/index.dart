import 'package:dart_frog/dart_frog.dart';

/// `GET /`: identificação da API.
Response onRequest(RequestContext context) {
  return Response.json(
    body: {'api': 'Gestor de Frotas', 'versao': '1.0.0'},
  );
}
