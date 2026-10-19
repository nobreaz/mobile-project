import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:project/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro vindo da API (ou da falta de conexão), já com mensagem em português.
class ApiError implements Exception {
  const ApiError(this.message, {this.statusCode = 0, this.fields = const {}});

  /// 0 = não chegou ao servidor (sem rede, API fora do ar, tempo esgotado).
  final int statusCode;
  final String message;

  /// Problema de cada campo (ex.: {'email': 'E-mail inválido.'}).
  final Map<String, String> fields;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Chamadas HTTP para a API, sempre com o token do usuário logado.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();
  static const _timeout = Duration(seconds: 15);

  /// Chamado quando a API responde 401 (sessão expirada ou revogada).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, Object body) => _send('POST', path, body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final request = http.Request(method, Uri.parse('${AppConfig.apiUrl}$path'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiError('O servidor demorou para responder. Tente de novo.');
    } on http.ClientException {
      throw const ApiError(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    }

    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = ApiError(
      decoded is Map && decoded['erro'] is String
          ? decoded['erro'] as String
          : 'Erro inesperado (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
      fields: decoded is Map && decoded['campos'] is Map
          ? (decoded['campos'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            )
          : const {},
    );
    if (error.isUnauthorized) onUnauthorized?.call();
    throw error;
  }
}
