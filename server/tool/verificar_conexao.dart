// Diagnóstico da configuração (server/.env). Não altera nada.
// Uso, dentro de server/:  dart run tool/verificar_conexao.dart
//
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:frota_server/src/config.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

Future<void> main() async {
  var ok = true;
  void check(String label, {required bool passed, String? detail}) {
    ok &= passed;
    print('${passed ? '✓' : '✗'} $label${detail == null ? '' : ': $detail'}');
  }

  final config = Config.fromEnvironment();

  // 1) Banco
  final db = Pool<void>.withUrl(config.databaseUrl);
  try {
    final tables = await db.execute(
      'SELECT table_name FROM information_schema.tables '
      "WHERE table_schema = 'public' ORDER BY 1",
    );
    check('Conexão com o banco', passed: true);
    final names = tables.map((r) => r.first! as String).toSet();
    const expected = {'usuarios', 'veiculos', 'solicitacoes', 'notificacoes'};
    check(
      'Migration aplicada',
      passed: names.containsAll(expected),
      detail: 'tabelas: ${names.join(', ')}',
    );

    final approvers = await db.execute(
      "SELECT count(*) FROM usuarios WHERE perfil = 'aprovador' AND ativo",
    );
    final count = approvers.first.first! as int;
    check('Aprovador ativo cadastrado', passed: count > 0, detail: '$count');
  } on Object catch (e) {
    check('Conexão com o banco', passed: false, detail: '$e');
  } finally {
    await db.close();
  }

  // 2) Supabase Auth com a chave secreta (lista 1 usuário, só leitura)
  final secret = config.supabaseSecretKey;
  final response = await http.get(
    config.supabaseUrl.resolve('/auth/v1/admin/users?per_page=1'),
    headers: {
      'apikey': secret,
      if (secret.startsWith('eyJ')) 'Authorization': 'Bearer $secret',
    },
  );
  check(
    'Chave secreta aceita pela API admin do Auth',
    passed: response.statusCode == 200,
    detail: response.statusCode == 200
        ? 'HTTP 200'
        : 'HTTP ${response.statusCode} ${response.body}',
  );

  // 3) Configuração do login: cadastro público deve estar desligado
  final settings = await http.get(
    config.supabaseUrl.resolve('/auth/v1/settings'),
    headers: {'apikey': config.supabasePublishableKey},
  );
  if (settings.statusCode == 200) {
    final json = jsonDecode(settings.body) as Map<String, dynamic>;
    check(
      'Cadastro público desligado',
      passed: json['disable_signup'] == true,
      detail: 'disable_signup = ${json['disable_signup']}',
    );
  } else {
    check(
      'Chave publishable aceita',
      passed: false,
      detail: 'HTTP ${settings.statusCode}',
    );
  }

  print(ok ? '\nTudo certo.' : '\nHá itens para corrigir (veja ✗ acima).');
  exit(ok ? 0 : 1);
}
