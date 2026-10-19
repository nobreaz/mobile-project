import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/health.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

void main() {
  late _MockRequestContext context;
  late _MockRequest request;

  setUp(() {
    context = _MockRequestContext();
    request = _MockRequest();
    when(() => context.request).thenReturn(request);
  });

  test('GET /health responde ok com os status do frota_core', () async {
    when(() => request.method).thenReturn(HttpMethod.get);

    final response = route.onRequest(context);
    final body = await response.json() as Map<String, dynamic>;

    expect(response.statusCode, equals(HttpStatus.ok));
    expect(body['status'], equals('ok'));
    expect(
      body['statusSolicitacao'],
      contains(equals({'id': 'pendente', 'label': 'Pendente'})),
    );
  });

  test('outros métodos respondem 405', () {
    when(() => request.method).thenReturn(HttpMethod.post);

    final response = route.onRequest(context);

    expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
  });
}
