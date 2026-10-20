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
        // 23P01 = restrição EXCLUDE (conflito de agenda, RN 4.3 e 4.4):
        // acontece quando duas pessoas agem ao mesmo tempo e a conferência
        // da API não pegou.
        if (e.code == '23505' || e.code == '23P01') {
          return Response.json(
            statusCode: HttpStatus.conflict,
            body: {
              'erro':
                  _constraintMessages[e.constraintName] ??
                  'Registro duplicado (${e.constraintName}).',
            },
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

/// Mensagens para as restrições do banco que o usuário pode esbarrar.
const _constraintMessages = {
  'usuarios_email_key': 'Já existe um usuário com este e-mail.',
  'veiculos_placa_key': 'Já existe um veículo com esta placa.',
  'veiculos_chassi_key': 'Já existe um veículo com este chassi.',
  'veiculo_sem_conflito':
      'O veículo já está reservado neste período. Escolha outro.',
  'usuario_sem_conflito':
      'Você já tem uma solicitação ativa nesse período. '
      'Escolha outro horário ou cancele a anterior.',
};

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
  return (handler) {
    return (context) {
      checkProfile(context.read<UserModel>(), allowed);
      return handler(context);
    };
  };
}

/// Mesma conferência de [requireProfile], para rotas em que cada método
/// tem um perfil diferente (ex.: GET para todos, POST só Administrador).
void checkProfile(
  UserModel me,
  Set<UserProfile> allowed, [
  String action = 'acessar este recurso',
]) {
  if (!allowed.contains(me.profile)) {
    final names = allowed.map((p) => p.label).join(' ou ');
    throw ApiException.forbidden('Apenas o perfil $names pode $action.');
  }
}

/// Lê o corpo como objeto JSON (`{...}`).
Future<Map<String, dynamic>> readJsonObject(RequestContext context) async {
  final body = await context.request.json();
  if (body is! Map<String, dynamic>) {
    throw const ApiException.badRequest('O corpo deve ser um objeto JSON.');
  }
  return body;
}

/// Id numérico vindo da URL (`/veiculos/{id}`). Inválido = não encontrado.
int pathId(String raw, String notFoundMessage) {
  final id = int.tryParse(raw);
  if (id == null || id <= 0) throw ApiException.notFound(notFoundMessage);
  return id;
}
