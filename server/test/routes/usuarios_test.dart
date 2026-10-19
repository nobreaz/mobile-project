import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/me/index.dart' as me_route;
import '../../routes/usuarios/[id].dart' as usuario_route;
import '../../routes/usuarios/index.dart' as usuarios_route;
import '../helpers.dart';

Matcher _apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late MockUsuariosRepository repository;
  late MockSupabaseAuth auth;
  final approver = user(profile: UserProfile.aprovador);

  setUpAll(() => registerFallbackValue(user()));

  setUp(() {
    repository = MockUsuariosRepository();
    auth = MockSupabaseAuth();
  });

  group('POST /usuarios', () {
    final body = {
      'name': 'Ana Ribeiro',
      'email': 'ana@empresa.com',
      'role': 'Técnica',
      'department': 'Operações',
      'password': 'senha1!',
    };

    test('cria o login e o cadastro → 201', () async {
      when(() => repository.emailExists(any())).thenAnswer((_) async => false);
      when(
        () => auth.createUser(email: 'ana@empresa.com', password: 'senha1!'),
      ).thenAnswer((_) async => 'uuid-ana');
      when(
        () => repository.insert(any(), authId: 'uuid-ana'),
      ).thenAnswer((i) async => i.positionalArguments.first as UserModel);

      final response = await usuarios_route.onRequest(
        contextFor(
          jsonRequest('POST', '/usuarios', body),
          repository: repository,
          auth: auth,
          me: approver,
        ),
      );

      expect(response.statusCode, 201);
      expect(await response.json(), containsPair('email', 'ana@empresa.com'));
    });

    test('e-mail já cadastrado → 409, sem criar login', () {
      when(() => repository.emailExists(any())).thenAnswer((_) async => true);

      expect(
        () => usuarios_route.onRequest(
          contextFor(
            jsonRequest('POST', '/usuarios', body),
            repository: repository,
            auth: auth,
          ),
        ),
        _apiError(409),
      );
      verifyNever(
        () => auth.createUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    });

    test('se gravar no banco falhar, apaga o login criado', () async {
      when(() => repository.emailExists(any())).thenAnswer((_) async => false);
      when(
        () => auth.createUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => 'uuid-ana');
      when(
        () => repository.insert(any(), authId: any(named: 'authId')),
      ).thenThrow(StateError('banco fora do ar'));
      when(() => auth.deleteUser('uuid-ana')).thenAnswer((_) async {});

      await expectLater(
        usuarios_route.onRequest(
          contextFor(
            jsonRequest('POST', '/usuarios', body),
            repository: repository,
            auth: auth,
          ),
        ),
        throwsStateError,
      );
      verify(() => auth.deleteUser('uuid-ana')).called(1);
    });
  });

  group('PATCH /usuarios/{id}', () {
    test('aprovador não pode desativar a si mesmo → 403', () {
      expect(
        () => usuario_route.onRequest(
          contextFor(
            jsonRequest('PATCH', '/usuarios/1', {'active': false}),
            repository: repository,
            auth: auth,
            me: approver,
          ),
          '1',
        ),
        _apiError(403),
      );
    });

    test('desativar outro usuário bloqueia o login dele', () async {
      final ana = user(id: 2);
      when(() => repository.findById(2)).thenAnswer((_) async => ana);
      when(
        () => repository.update(2, {'ativo': false}),
      ).thenAnswer((_) async => user(id: 2, active: false));
      when(() => repository.authIdOf(2)).thenAnswer((_) async => 'uuid-ana');
      when(
        () => auth.setBanned('uuid-ana', banned: true),
      ).thenAnswer((_) async {});

      final response = await usuario_route.onRequest(
        contextFor(
          jsonRequest('PATCH', '/usuarios/2', {'active': false}),
          repository: repository,
          auth: auth,
          me: approver,
        ),
        '2',
      );

      expect(response.statusCode, 200);
      expect(await response.json(), containsPair('active', false));
      verify(() => auth.setBanned('uuid-ana', banned: true)).called(1);
    });

    test('id inexistente → 404', () {
      when(() => repository.findById(99)).thenAnswer((_) async => null);
      expect(
        () => usuario_route.onRequest(
          contextFor(
            jsonRequest('PATCH', '/usuarios/99', {'name': 'X'}),
            repository: repository,
            auth: auth,
            me: approver,
          ),
          '99',
        ),
        _apiError(404),
      );
    });
  });

  group('/me', () {
    test('GET devolve o usuário logado', () async {
      final response = await me_route.onRequest(
        contextFor(jsonRequest('GET', '/me'), me: user(id: 7)),
      );
      expect(await response.json(), containsPair('id', 7));
    });

    test('PATCH altera só o telefone', () async {
      when(
        () => repository.update(7, {'telefone': '(22) 9999-0000'}),
      ).thenAnswer((_) async => user(id: 7));

      final response = await me_route.onRequest(
        contextFor(
          jsonRequest('PATCH', '/me', {'phone': '(22) 9999-0000'}),
          repository: repository,
          me: user(id: 7),
        ),
      );

      expect(response.statusCode, 200);
    });
  });
}
