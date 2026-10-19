import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/user_input.dart';
import 'package:frota_server/src/usuarios_repository.dart';

/// `/usuarios/{id}` (só Aprovador).
/// - GET: detalhe do usuário.
/// - PATCH: altera dados, perfil ou ativa/desativa o acesso.
///   Usuário nunca é apagado: desativar bloqueia o login e mantém o histórico.
Future<Response> onRequest(RequestContext context, String id) async {
  final userId = int.tryParse(id);
  if (userId == null) {
    throw const ApiException.notFound('Usuário não encontrado.');
  }

  final repository = context.read<UsuariosRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final user = await repository.findById(userId);
      if (user == null) {
        throw const ApiException.notFound('Usuário não encontrado.');
      }
      return Response.json(body: user.toJson());

    case HttpMethod.patch:
      final changes = parseUserUpdate(await readJsonObject(context));

      // O Aprovador não pode tirar o próprio acesso nem o próprio perfil:
      // evita que o sistema fique sem ninguém para administrar.
      final me = context.read<UserModel>();
      final selfLockout =
          changes['ativo'] == false ||
          (changes.containsKey('perfil') &&
              changes['perfil'] != UserProfile.aprovador.name);
      if (me.id == userId && selfLockout) {
        throw const ApiException.forbidden(
          'Você não pode desativar nem rebaixar o próprio usuário.',
        );
      }

      final before = await repository.findById(userId);
      if (before == null) {
        throw const ApiException.notFound('Usuário não encontrado.');
      }

      final updated = await repository.update(userId, changes);

      // O banco (coluna `ativo`) é quem manda: a API recusa usuário inativo
      // em toda requisição. Bloquear o login no Supabase impede também que
      // ele obtenha novos tokens.
      final active = changes['ativo'] as bool?;
      if (active != null && active != before.active) {
        final authId = await repository.authIdOf(userId);
        try {
          await context.read<SupabaseAuth>().setBanned(
            authId!,
            banned: !active,
          );
        } on SupabaseAuthException catch (e) {
          stderr.writeln('Aviso: cadastro atualizado, mas $e');
        }
      }

      return Response.json(body: updated!.toJson());

    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}
