import 'dart:io';

/// Erro que vira uma resposta HTTP com JSON `{"erro": ..., "campos": {...}}`.
///
/// As rotas lançam esta exceção e o middleware global (`routes/_middleware`)
/// transforma em resposta. Assim nenhuma rota monta resposta de erro na mão.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.fields});

  /// 400: dados inválidos. [fields] diz o problema de cada campo.
  const ApiException.badRequest(String message, {Map<String, String>? fields})
    : this(HttpStatus.badRequest, message, fields: fields);

  /// 401: sem login ou login expirado.
  const ApiException.unauthorized([
    String message = 'Faça login para continuar.',
  ]) : this(HttpStatus.unauthorized, message);

  /// 403: logado, mas sem permissão.
  const ApiException.forbidden([
    String message = 'Você não tem permissão para esta ação.',
  ]) : this(HttpStatus.forbidden, message);

  const ApiException.notFound([String message = 'Não encontrado.'])
    : this(HttpStatus.notFound, message);

  /// 409: conflito com o que já existe (ex.: e-mail repetido).
  const ApiException.conflict(String message)
    : this(HttpStatus.conflict, message);

  const ApiException.methodNotAllowed()
    : this(HttpStatus.methodNotAllowed, 'Método não permitido.');

  final int statusCode;
  final String message;
  final Map<String, String>? fields;

  Map<String, Object?> toJson() => {
    'erro': message,
    if (fields != null && fields!.isNotEmpty) 'campos': fields,
  };

  @override
  String toString() => 'ApiException($statusCode): $message';
}
