import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers.dart';

Matcher _apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late MockUsuariosRepository repository;
  late MockSupabaseAuth auth;

  setUp(() {
    repository = MockUsuariosRepository();
    auth = MockSupabaseAuth();
  });

  Future<Response> ok(RequestContext _) async => Response(body: 'ok');

  group('requireUser', () {
    Request withToken([String? token]) => Request(
      'GET',
      Uri.parse('http://localhost/me'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    test('sem token → 401', () {
      final context = contextFor(
        withToken(),
        repository: repository,
        auth: auth,
      );
      expect(() => requireUser()(ok)(context), _apiError(401));
    });

    test('token inválido → 401', () {
      when(() => auth.userIdFromToken('ruim')).thenAnswer((_) async => null);
      final context = contextFor(
        withToken('ruim'),
        repository: repository,
        auth: auth,
      );
      expect(() => requireUser()(ok)(context), _apiError(401));
    });

    test('login sem cadastro → 403', () {
      when(() => auth.userIdFromToken('t')).thenAnswer((_) async => 'uuid');
      when(() => repository.findByAuthId('uuid')).thenAnswer((_) async => null);
      final context = contextFor(
        withToken('t'),
        repository: repository,
        auth: auth,
      );
      expect(() => requireUser()(ok)(context), _apiError(403));
    });

    test('usuário desativado → 403', () {
      when(() => auth.userIdFromToken('t')).thenAnswer((_) async => 'uuid');
      when(
        () => repository.findByAuthId('uuid'),
      ).thenAnswer((_) async => user(active: false));
      final context = contextFor(
        withToken('t'),
        repository: repository,
        auth: auth,
      );
      expect(() => requireUser()(ok)(context), _apiError(403));
    });

    test('usuário ativo segue e fica disponível para a rota', () async {
      final me = user();
      when(() => auth.userIdFromToken('t')).thenAnswer((_) async => 'uuid');
      when(() => repository.findByAuthId('uuid')).thenAnswer((_) async => me);
      final context = contextFor(
        withToken('t'),
        repository: repository,
        auth: auth,
      );
      when(() => context.provide<UserModel>(any())).thenReturn(context);

      final response = await requireUser()(ok)(context);

      expect(response.statusCode, 200);
      final provided =
          verify(() => context.provide<UserModel>(captureAny())).captured.single
              as UserModel Function();
      expect(provided(), same(me));
    });
  });

  group('requireProfile (gestão de usuários: só administrador)', () {
    final onlyAdmin = requireProfile({UserProfile.administrador});

    for (final profile in [UserProfile.padrao, UserProfile.aprovador]) {
      test('${profile.label} → 403', () {
        final context = contextFor(
          jsonRequest('GET', '/usuarios'),
          me: user(profile: profile),
        );
        expect(() => onlyAdmin(ok)(context), _apiError(403));
      });
    }

    test('Administrador segue', () async {
      final context = contextFor(
        jsonRequest('GET', '/usuarios'),
        me: user(profile: UserProfile.administrador),
      );
      expect((await onlyAdmin(ok)(context)).statusCode, 200);
    });
  });

  test('errorHandler transforma ApiException em JSON', () async {
    final context = contextFor(jsonRequest('GET', '/x'));
    Response fails(RequestContext _) => throw const ApiException.badRequest(
      'inválido',
      fields: {'name': 'obrigatório'},
    );

    final response = await errorHandler()(fails)(context);

    expect(response.statusCode, 400);
    expect(await response.json(), {
      'erro': 'inválido',
      'campos': {'name': 'obrigatório'},
    });
  });
}
