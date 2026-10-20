import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/relatorios_repository.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';

/// Períodos aceitos pelo `GET /relatorios?dias=N`.
const reportPeriods = {7, 30, 90, 365};

/// Monta o relatório dos últimos [days] dias até [now].
///
/// Os números vêm de consultas agregadas no banco; os alertas de veículo
/// e CNH usam as mesmas regras de vencimento do app (frota_core).
Future<FleetReport> buildFleetReport({
  required RelatoriosRepository reports,
  required VeiculosRepository vehicles,
  required UsuariosRepository users,
  required int days,
  DateTime? now,
}) async {
  final to = now ?? DateTime.now();
  final from = to.subtract(Duration(days: days));
  // Até ~3 meses, por semana (dá de 2 a 13 barras); acima, por mês.
  final granularity = days <= 92
      ? TrendGranularity.week
      : TrendGranularity.month;

  final totals = await reports.totals(from, to);
  final statuses = await reports.statuses(from, to);
  final trend = await reports.trend(from, to, granularity);
  final topUsers = await reports.topUsers(from, to);
  final fleet = await reports.vehicles(from, to);
  final departments = await reports.departments(from, to);
  final approvers = await reports.approvers(from, to);

  final alerts = [
    ...await reports.requestAlerts(),
    for (final v in await vehicles.list()) ...vehicleAlerts(v),
    for (final u in await users.list()) ?driverAlert(u),
  ];

  return FleetReport(
    days: days,
    granularity: granularity,
    trips: totals.trips,
    finishedTrips: totals.finishedTrips,
    lateReturns: totals.lateReturns,
    requests: totals.requests,
    statuses: statuses,
    trend: trend,
    users: topUsers,
    vehicles: fleet,
    departments: departments,
    approvers: approvers,
    // Críticos primeiro, mantendo a ordem de cada grupo.
    alerts: [
      ...alerts.where((a) => a.critical),
      ...alerts.where((a) => !a.critical),
    ],
  );
}
