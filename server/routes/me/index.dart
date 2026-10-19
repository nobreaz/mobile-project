import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/user_input.dart';
import 'package:frota_server/src/usuarios_repository.dart';

/// `/me`: o usuário logado.
/// - GET: dados do perfil (o app chama logo depois do login).
/// - PATCH: altera o próprio telefone (único dado editável pelo usuário).
Future<Response> onRequest(RequestContext context) async {
  final me = context.read<UserModel>();

  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(body: me.toJson());

    case HttpMethod.patch:
      final changes = parseMeUpdate(await readJsonObject(context));
      final updated = await context.read<UsuariosRepository>().update(
        me.id,
        changes,
      );
      return Response.json(body: updated!.toJson());

    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}
