import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/user_input.dart';
import 'package:frota_server/src/usuarios_repository.dart';

/// `/usuarios` (só Aprovador).
/// - GET: lista todos os usuários (ativos primeiro).
/// - POST: cadastra um colaborador e cria o login dele (RF 3.1.3).
Future<Response> onRequest(RequestContext context) async {
  final repository = context.read<UsuariosRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final users = await repository.list();
      return Response.json(body: [for (final u in users) u.toJson()]);

    case HttpMethod.post:
      final input = NewUserInput.fromJson(await readJsonObject(context));

      if (await repository.emailExists(input.user.email)) {
        throw const ApiException.conflict(
          'Já existe um usuário com este e-mail.',
        );
      }

      // 1) Cria o login no Supabase Auth; 2) grava o cadastro no banco.
      // Se o passo 2 falhar, desfaz o 1 para não sobrar login sem cadastro.
      final auth = context.read<SupabaseAuth>();
      final authId = await auth.createUser(
        email: input.user.email,
        password: input.password,
      );
      try {
        final created = await repository.insert(input.user, authId: authId);
        return Response.json(
          statusCode: HttpStatus.created,
          body: created.toJson(),
        );
      } catch (_) {
        await auth.deleteUser(authId);
        rethrow;
      }

    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}
