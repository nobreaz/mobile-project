import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/supabase_auth.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:postgres/postgres.dart';

/// Transforma exceções em respostas JSON padronizadas.
Middleware errorHandler() {
  return (handler) {
    return (context) async {
      try {
        return await handler(context);
      } on ApiException catch (e) {
        return Response.json(statusCode: e.statusCode, body: e.toJson());
      } on FormatException {
        return Response.json(
          statusCode: HttpStatus.badRequest,
          body: {'erro': 'JSON inválido no corpo da requisição.'},
        );
      } on ServerException catch (e) {
        // 23505 = valor único repetido (ex.: e-mail já cadastrado).
        if (e.code == '23505') {
          return Response.json(
            statusCode: HttpStatus.conflict,
            body: {'erro': 'Registro duplicado (${e.constraintName}).'},
          );
        }
        stderr.writeln('Erro do banco: $e');
        return _internalError();
      } on Object catch (e, stack) {
        stderr
          ..writeln('Erro inesperado: $e')
          ..writeln(stack);
        return _internalError();
      }
    };
  };
}

Response _internalError() => Response.json(
  statusCode: HttpStatus.internalServerError,
  body: {'erro': 'Erro interno. Tente novamente em instantes.'},
);

/// Libera chamadas do app rodando no navegador (Flutter web).
/// O login vai no cabeçalho Authorization, não em cookie, então `*` é seguro.
Middleware cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
  return (handler) {
    return (context) async {
      if (context.request.method == HttpMethod.options) {
        return Response(headers: headers);
      }
      final response = await handler(context);
      return response.copyWith(headers: {...response.headers, ...headers});
    };
  };
}

/// Exige login (RF 3.1.1). Confere o token do Supabase, carrega o usuário
/// do banco e o disponibiliza para a rota com `context.read<UserModel>()`.
Middleware requireUser() {
  return (handler) {
    return (context) async {
      final header = context.request.headers[HttpHeaders.authorizationHeader];
      if (header == null || !header.startsWith('Bearer ')) {
        throw const ApiException.unauthorized();
      }

      final authId = await context.read<SupabaseAuth>().userIdFromToken(
        header.substring('Bearer '.length).trim(),
      );
      if (authId == null) {
        throw const ApiException.unauthorized(
          'Sessão expirada. Faça login novamente.',
        );
      }

      final user = await context.read<UsuariosRepository>().findByAuthId(
        authId,
      );
      if (user == null) {
        throw const ApiException.forbidden(
          'Seu login não está vinculado a um cadastro. '
          'Procure o Administrador.',
        );
      }
      if (!user.active) {
        throw const ApiException.forbidden(
          'Seu acesso está desativado. Procure o Administrador.',
        );
      }

      return handler(context.provide<UserModel>(() => user));
    };
  };
}

/// Só passa quem tem um dos [allowed] perfis (RF 3.1.2 e RNF 6.3).
/// Usar sempre DENTRO de [requireUser].
Middleware requireProfile(Set<UserProfile> allowed) {
  final names = allowed.map((p) => p.label).join(' ou ');
  return (handler) {
    return (context) {
      if (!allowed.contains(context.read<UserModel>().profile)) {
        throw ApiException.forbidden(
          'Apenas o perfil $names pode acessar este recurso.',
        );
      }
      return handler(context);
    };
  };
}

/// Lê o corpo como objeto JSON (`{...}`).
Future<Map<String, dynamic>> readJsonObject(RequestContext context) async {
  final body = await context.request.json();
  if (body is! Map<String, dynamic>) {
    throw const ApiException.badRequest('O corpo deve ser um objeto JSON.');
  }
  return body;
}
