import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/middleware.dart';
import 'package:frota_server/src/request_input.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';

/// `/solicitacoes`
///
/// GET: lista. Quem vê o quê (RNF 6.3):
/// - Aprovador: todas, decididas por ele ou por outro aprovador.
/// - Administrador: todas, só leitura (agenda geral, relatórios).
/// - Padrão: só as próprias (RF 3.3.9, histórico).
///
/// Filtros (query string, opcionais):
/// - `status=aprovada,emUso,finalizada`: um ou mais status, separados
///   por vírgula (nomes de `RequestStatus`).
/// - `aprovadorId=7`: só as decididas por esse aprovador ("só as minhas").
///
/// POST: nova solicitação (RF 3.3.1), só perfil Padrão com CNH válida.
/// Corpo: `reason`, `destination`, `passengers`, `departure` (ISO 8601 com
/// fuso), `returnDate` (`AAAA-MM-DD`) e `returnPeriod` (`manha`/`tarde`).
Future<Response> onRequest(RequestContext context) async {
  switch (context.request.method) {
    case HttpMethod.get:
      return _list(context);
    case HttpMethod.post:
      final me = context.read<UserModel>();
      checkProfile(me, {UserProfile.padrao}, 'solicitar veículos');
      final fields = RequestFields.fromJson(
        await readJsonObject(context),
        partial: false,
      );
      final created = await context.read<FrotaService>().createRequest(
        me,
        fields,
      );
      return Response.json(
        statusCode: HttpStatus.created,
        body: created.toJson(),
      );
    // ignore: no_default_cases
    default:
      throw const ApiException.methodNotAllowed();
  }
}

Future<Response> _list(RequestContext context) async {
  final me = context.read<UserModel>();
  final query = context.request.uri.queryParameters;

  final statuses = _parseStatuses(query['status']);
  final approverId = _parseId(query['aprovadorId'], 'aprovadorId');

  final requests = await context.read<SolicitacoesRepository>().list(
    statuses: statuses,
    // Padrão nunca vê solicitações de outras pessoas.
    requesterId: me.profile == UserProfile.padrao ? me.id : null,
    approverId: approverId,
  );

  return Response.json(body: [for (final r in requests) r.toJson()]);
}

Set<RequestStatus>? _parseStatuses(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  final statuses = <RequestStatus>{};
  for (final name in raw.split(',').map((s) => s.trim())) {
    final match = RequestStatus.values.where((s) => s.name == name);
    if (match.isEmpty) {
      throw ApiException.badRequest(
        'Status inválido: "$name".',
        fields: {
          'status':
              'Use: ${RequestStatus.values.map((s) => s.name).join(', ')}.',
        },
      );
    }
    statuses.add(match.single);
  }
  return statuses;
}

int? _parseId(String? raw, String field) {
  if (raw == null || raw.isEmpty) return null;
  final id = int.tryParse(raw);
  if (id == null) {
    throw ApiException.badRequest(
      'Filtro inválido.',
      fields: {field: 'Deve ser um número.'},
    );
  }
  return id;
}
