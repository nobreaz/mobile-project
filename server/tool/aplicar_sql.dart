// Executa um arquivo .sql no banco do server/.env (alternativa ao SQL
// Editor do painel e à Supabase CLI).
//
// Uso, dentro de server/:
//   dart run tool/aplicar_sql.dart ../supabase/migrations/ARQUIVO.sql
//
// Cuidado: altera o banco de verdade. Uma migration só deve ser aplicada
// uma vez; confira antes se ela já não foi aplicada.
//
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:frota_server/src/config.dart';
import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('Uso: dart run tool/aplicar_sql.dart CAMINHO/ARQUIVO.sql');
    exit(64);
  }
  final file = File(args.single);
  if (!file.existsSync()) {
    print('Arquivo não encontrado: ${file.path}');
    exit(66);
  }

  final db = Pool<void>.withUrl(Config.fromEnvironment().databaseUrl);
  try {
    // Modo simple: aceita vários comandos no mesmo arquivo
    // (o PostgreSQL roda tudo numa transação implícita: tudo ou nada).
    await db.execute(file.readAsStringSync(), queryMode: QueryMode.simple);
    print('✓ Aplicado: ${file.path}');
  } on ServerException catch (e) {
    print('✗ Erro do banco (nada foi aplicado): ${e.message}');
    exitCode = 1;
  } finally {
    await db.close();
  }
}
