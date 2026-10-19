import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/user_input.dart';
import 'package:test/test.dart';

Matcher _badRequestWith(List<String> fields) => throwsA(
  isA<ApiException>()
      .having((e) => e.statusCode, 'status', 400)
      .having(
        (e) => e.fields?.keys.toList(),
        'campos',
        unorderedEquals(fields),
      ),
);

void main() {
  final valid = {
    'name': ' Ana Ribeiro ',
    'email': 'Ana.Ribeiro@Empresa.com',
    'role': 'Técnica',
    'department': 'Operações',
    'password': 'senha1!',
    'cnhExpiry': '2029-03-10',
  };

  group('NewUserInput', () {
    test('aceita dados válidos, normaliza e usa perfil padrão', () {
      final input = NewUserInput.fromJson(valid);

      expect(input.user.name, 'Ana Ribeiro');
      expect(input.user.email, 'ana.ribeiro@empresa.com');
      expect(input.user.profile, UserProfile.padrao);
      expect(input.user.cnhExpiry, DateTime(2029, 3, 10));
      expect(input.password, 'senha1!');
    });

    test('junta todos os erros de uma vez', () {
      expect(
        () => NewUserInput.fromJson({'email': 'invalido', 'password': 'abc'}),
        _badRequestWith(['name', 'email', 'role', 'department', 'password']),
      );
    });

    test('senha fora da regra 6.2 é recusada', () {
      for (final weak in ['abc!1', 'abcdef!', 'abcdef1']) {
        expect(
          () => NewUserInput.fromJson({...valid, 'password': weak}),
          _badRequestWith(['password']),
          reason: weak,
        );
      }
    });

    test('perfil e data inválidos são recusados', () {
      expect(
        () => NewUserInput.fromJson({
          ...valid,
          'profile': 'admin',
          'cnhExpiry': '10/03/2029',
        }),
        _badRequestWith(['profile', 'cnhExpiry']),
      );
    });
  });

  group('parseUserUpdate', () {
    test('traduz só os campos enviados para as colunas do banco', () {
      expect(
        parseUserUpdate({
          'name': 'Novo Nome',
          'phone': '',
          'profile': 'aprovador',
          'active': false,
        }),
        {
          'nome': 'Novo Nome',
          'telefone': null,
          'perfil': 'aprovador',
          'ativo': false,
        },
      );
    });

    test('e-mail não pode ser alterado', () {
      expect(
        () => parseUserUpdate({'email': 'outro@empresa.com'}),
        _badRequestWith(['email']),
      );
    });
  });

  group('parseMeUpdate', () {
    test('aceita só o telefone', () {
      expect(parseMeUpdate({'phone': '(22) 9999-0000'}), {
        'telefone': '(22) 9999-0000',
      });
    });

    test('recusa qualquer outro campo', () {
      expect(
        () => parseMeUpdate({'phone': '1', 'profile': 'aprovador'}),
        _badRequestWith(['profile']),
      );
    });
  });
}
