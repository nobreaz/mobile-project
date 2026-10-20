import 'package:dart_frog/dart_frog.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/relatorios.dart';
import 'package:frota_server/src/relatorios_repository.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';

/// `GET /relatorios?dias=30`: indicadores, rankings e alertas da frota
/// (tela "Ver Relatórios"). `dias`: 7, 30 (padrão), 90 ou 365.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    throw const ApiException.methodNotAllowed();
  }

  final raw = context.request.uri.queryParameters['dias'];
  final days = raw == null ? 30 : int.tryParse(raw);
  if (days == null || !reportPeriods.contains(days)) {
    throw ApiException.badRequest(
      'Período inválido.',
      fields: {'dias': 'Use ${reportPeriods.join(', ')}.'},
    );
  }

  final report = await buildFleetReport(
    reports: context.read<RelatoriosRepository>(),
    vehicles: context.read<VeiculosRepository>(),
    users: context.read<UsuariosRepository>(),
    days: days,
  );
  return Response.json(body: report.toJson());
}
