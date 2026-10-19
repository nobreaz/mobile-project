import 'dart:convert';

import 'package:frota_server/src/api_exception.dart';
import 'package:http/http.dart' as http;

/// Conversa com o Supabase Auth (login, senhas e bloqueio de acesso).
///
/// O app faz login direto no Supabase e manda o token para a API.
/// Aqui a API só confere o token e, para o Aprovador, cria e bloqueia logins.
class SupabaseAuth {
  SupabaseAuth({
    required this._url,
    required this._publishableKey,
    required this._secretKey,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Uri _url;
  final String _publishableKey;
  final String _secretKey;
  final http.Client _client;
  final DateTime Function() _clock;

  /// Tokens já conferidos, para não perguntar ao Supabase a cada requisição.
  /// Curto de propósito: um usuário bloqueado perde o acesso em até 1 minuto
  /// (e a API também confere `ativo` no banco a cada requisição).
  static const _cacheTtl = Duration(minutes: 1);
  final _cache = <String, ({String authId, DateTime until})>{};

  Uri _endpoint(String path) => _url.resolve('/auth/v1/$path');

  /// Cabeçalhos para as rotas de administração.
  /// Chaves novas (`sb_secret_...`) vão só no `apikey`; a chave legada
  /// `service_role` (um JWT, começa com `eyJ`) também vai como Bearer.
  Map<String, String> get _adminHeaders => {
    'apikey': _secretKey,
    if (_secretKey.startsWith('eyJ')) 'Authorization': 'Bearer $_secretKey',
    'Content-Type': 'application/json',
  };

  /// Confere o token de acesso enviado pelo app.
  /// Devolve o id do login (uuid) ou `null` se o token for inválido/expirado.
  ///
  /// Usa `GET /auth/v1/user`, o método que o Supabase recomenda para
  /// servidores próprios: funciona com qualquer tipo de chave de assinatura.
  Future<String?> userIdFromToken(String token) async {
    final now = _clock();
    final cached = _cache[token];
    if (cached != null && cached.until.isAfter(now)) return cached.authId;

    final response = await _client.get(
      _endpoint('user'),
      headers: {'apikey': _publishableKey, 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      _cache.remove(token);
      return null;
    }

    final authId = (jsonDecode(response.body) as Map<String, dynamic>)['id'];
    if (authId is! String) return null;

    _cache
      ..removeWhere((_, v) => !v.until.isAfter(now))
      ..[token] = (authId: authId, until: now.add(_cacheTtl));
    return authId;
  }

  /// Cria o login (e-mail já confirmado) com a senha inicial definida pelo
  /// Aprovador. Devolve o id do login.
  Future<String> createUser({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('admin/users'),
      headers: _adminHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'email_confirm': true,
      }),
    );

    if (response.statusCode == 422 || response.statusCode == 409) {
      throw const ApiException.conflict(
        'Já existe um login com este e-mail.',
      );
    }
    _ensureSuccess(response, 'criar o login');
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  /// Bloqueia ou libera o login (usuário desativado/reativado).
  Future<void> setBanned(String authId, {required bool banned}) async {
    final response = await _client.put(
      _endpoint('admin/users/$authId'),
      headers: _adminHeaders,
      // ~100 anos = bloqueado até ser reativado.
      body: jsonEncode({'ban_duration': banned ? '876000h' : 'none'}),
    );
    _ensureSuccess(response, banned ? 'bloquear o login' : 'liberar o login');
  }

  /// Apaga um login. Usado só para desfazer um cadastro que falhou no meio.
  Future<void> deleteUser(String authId) async {
    final response = await _client.delete(
      _endpoint('admin/users/$authId'),
      headers: _adminHeaders,
    );
    _ensureSuccess(response, 'apagar o login');
  }

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw SupabaseAuthException(
      'Falha ao $action no Supabase Auth '
      '(HTTP ${response.statusCode}): ${response.body}',
    );
  }
}

/// Falha inesperada na comunicação com o Supabase Auth (vira HTTP 500).
class SupabaseAuthException implements Exception {
  const SupabaseAuthException(this.message);

  final String message;

  @override
  String toString() => 'SupabaseAuthException: $message';
}
