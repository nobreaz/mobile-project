import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/relatorios/index.dart' as route;
import '../helpers.dart';

void main() {
  late MockRelatoriosRepository reports;
  late MockVeiculosRepository vehicles;
  late MockUsuariosRepository users;
  final admin = user(profile: UserProfile.administrador);

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(TrendGranularity.week);
  });

  setUp(() {
    reports = MockRelatoriosRepository();
    vehicles = MockVeiculosRepository();
    users = MockUsuariosRepository();

    when(() => reports.totals(any(), any())).thenAnswer(
      (_) async => (
        trips: 3,
        finishedTrips: 2,
        lateReturns: 1,
        requests: 4,
      ),
    );
    when(
      () => reports.statuses(any(), any()),
    ).thenAnswer((_) async => {RequestStatus.finalizada: 2});
    when(() => reports.trend(any(), any(), any())).thenAnswer((_) async => []);
    when(() => reports.topUsers(any(), any())).thenAnswer(
      (_) async => [const RankingEntry(id: 3, label: 'Ana', trips: 3)],
    );
    when(() => reports.vehicles(any(), any())).thenAnswer((_) async => []);
    when(() => reports.departments(any(), any())).thenAnswer((_) async => []);
    when(() => reports.approvers(any(), any())).thenAnswer((_) async => []);
    when(() => reports.requestAlerts()).thenAnswer(
      (_) async => [
        const ReportAlert(
          kind: AlertKind.saidaSemAprovacao,
          critical: false,
          title: 'Ana · Macaé',
          message: 'Sai amanhã',
        ),
      ],
    );
    // Seguro vencido: alerta crítico, tem que vir antes do pendente.
    when(() => vehicles.list()).thenAnswer(
      (_) async => [vehicle()..insuranceExpiry = DateTime(2020)],
    );
    when(() => users.list()).thenAnswer((_) async => [user()]);
  });

  Future<Map<String, dynamic>> get(String path) async {
    final response = await route.onRequest(
      contextFor(
        jsonRequest('GET', path),
        me: admin,
        reports: reports,
        vehicles: vehicles,
        repository: users,
      ),
    );
    expect(response.statusCode, 200);
    return await response.json() as Map<String, dynamic>;
  }

  test('GET /relatorios: 30 dias por padrão, agrupado por semana', () async {
    final report = FleetReport.fromJson(await get('/relatorios'));

    expect(report.days, 30);
    expect(report.granularity, TrendGranularity.week);
    expect(report.users.single.label, 'Ana');
    expect(report.onTimeRate, 0.5);
    // Críticos primeiro; a CNH não informada do Padrão também aparece.
    expect(report.alerts.map((a) => (a.kind, a.critical)), [
      (AlertKind.seguro, true),
      (AlertKind.saidaSemAprovacao, false),
      (AlertKind.cnh, false),
    ]);
  });

  test('GET /relatorios?dias=365: agrupado por mês', () async {
    final json = await get('/relatorios?dias=365');
    expect(json['granularity'], 'month');
  });

  test('GET /relatorios?dias=15: período inválido → 400', () {
    expect(
      () => route.onRequest(
        contextFor(jsonRequest('GET', '/relatorios?dias=15'), me: admin),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 400)),
    );
  });
}
