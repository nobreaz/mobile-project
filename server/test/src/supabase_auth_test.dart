import 'dart:convert';

import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final url = Uri.parse('https://projeto.supabase.co');
  final requests = <http.Request>[];
  late DateTime now;

  SupabaseAuth build(
    http.Response Function(http.Request) respond, {
    String secretKey = 'sb_secret_abc',
  }) {
    requests.clear();
    now = DateTime(2026, 10, 19, 10);
    return SupabaseAuth(
      url: url,
      publishableKey: 'sb_publishable_xyz',
      secretKey: secretKey,
      clock: () => now,
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
  }

  group('userIdFromToken', () {
    test('token válido devolve o id e guarda em cache por 1 minuto', () async {
      final auth = build(
        (_) => http.Response(jsonEncode({'id': 'uuid-1'}), 200),
      );

      expect(await auth.userIdFromToken('tok'), 'uuid-1');
      expect(requests.single.url.path, '/auth/v1/user');
      expect(requests.single.headers['apikey'], 'sb_publishable_xyz');
      expect(requests.single.headers['Authorization'], 'Bearer tok');

      now = now.add(const Duration(seconds: 59));
      expect(await auth.userIdFromToken('tok'), 'uuid-1');
      expect(requests, hasLength(1), reason: 'usou o cache');

      now = now.add(const Duration(seconds: 2));
      await auth.userIdFromToken('tok');
      expect(requests, hasLength(2), reason: 'cache expirou');
    });

    test('token inválido devolve null', () async {
      final auth = build((_) => http.Response('{"msg":"invalid"}', 401));
      expect(await auth.userIdFromToken('ruim'), isNull);
    });
  });

  group('createUser', () {
    test('chave nova (sb_secret) vai só no apikey', () async {
      final auth = build(
        (_) => http.Response(jsonEncode({'id': 'uuid-novo'}), 200),
      );

      final id = await auth.createUser(email: 'a@b.com', password: 'abc12!');

      expect(id, 'uuid-novo');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/admin/users');
      expect(request.headers['apikey'], 'sb_secret_abc');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'email': 'a@b.com',
        'password': 'abc12!',
        'email_confirm': true,
      });
    });

    test('chave legada (JWT) também vai como Bearer', () async {
      final auth = build(
        (_) => http.Response(jsonEncode({'id': 'x'}), 200),
        secretKey: 'eyJlegado',
      );
      await auth.createUser(email: 'a@b.com', password: 'abc12!');
      expect(requests.single.headers['Authorization'], 'Bearer eyJlegado');
    });

    test('e-mail já existente vira 409', () async {
      final auth = build((_) => http.Response('{"msg":"exists"}', 422));
      expect(
        () => auth.createUser(email: 'a@b.com', password: 'abc12!'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });

  test('setBanned bloqueia e libera pelo ban_duration', () async {
    final auth = build((_) => http.Response('{}', 200));

    await auth.setBanned('uuid-1', banned: true);
    await auth.setBanned('uuid-1', banned: false);

    expect(requests.first.url.path, '/auth/v1/admin/users/uuid-1');
    expect(jsonDecode(requests.first.body), {'ban_duration': '876000h'});
    expect(jsonDecode(requests.last.body), {'ban_duration': 'none'});
  });

  test('erro inesperado do Supabase vira SupabaseAuthException', () {
    final auth = build((_) => http.Response('boom', 500));
    expect(
      () => auth.setBanned('uuid-1', banned: true),
      throwsA(isA<SupabaseAuthException>()),
    );
  });
}
