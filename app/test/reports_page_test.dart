import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/controllers/report_controller.dart';
import 'package:project/pages/reports_page.dart';

FleetReport sampleReport() => FleetReport(
  days: 90,
  granularity: TrendGranularity.week,
  trips: 23,
  finishedTrips: 21,
  lateReturns: 3,
  requests: 31,
  statuses: {
    RequestStatus.finalizada: 21,
    RequestStatus.emUso: 2,
    RequestStatus.pendente: 3,
    RequestStatus.recusada: 3,
    RequestStatus.cancelada: 2,
  },
  trend: [
    for (var i = 0; i < 13; i++)
      TrendPoint(
        start: DateTime(2026, 7, 27).add(Duration(days: 7 * i)),
        trips: const [1, 2, 0, 3, 1, 2, 4, 1, 0, 2, 3, 2, 2][i],
      ),
  ],
  users: const [
    RankingEntry(
      id: 3,
      label: 'Felipe Ribeiro',
      detail: 'Comercial',
      trips: 8,
      km: 1620,
      lateReturns: 2,
    ),
    RankingEntry(
      id: 4,
      label: 'Lualinda Andrade',
      detail: 'Operações',
      trips: 6,
      km: 980,
    ),
    RankingEntry(
      id: 5,
      label: 'Carlos Mendes',
      detail: 'Logística',
      trips: 4,
      km: 760,
      lateReturns: 1,
    ),
    RankingEntry(id: 6, label: 'Ana Souza', detail: 'TI', trips: 1, km: 120),
  ],
  vehicles: const [
    RankingEntry(
      id: 1,
      label: 'Fiat Strada',
      detail: 'ABC1D23',
      trips: 11,
      km: 2100,
    ),
    RankingEntry(id: 2, label: 'VW Gol', detail: 'XYZ9K88', trips: 9, km: 1480),
    RankingEntry(
      id: 3,
      label: 'Renault Master',
      detail: 'VAN0A11',
      trips: 3,
      km: 600,
    ),
    RankingEntry(id: 4, label: 'Fiat Uno', detail: 'UNO2B22', trips: 0),
  ],
  departments: const [
    RankingEntry(label: 'Comercial', trips: 10, km: 1900),
    RankingEntry(label: 'Operações', trips: 8, km: 1400),
    RankingEntry(label: 'TI', trips: 5, km: 880),
  ],
  approvers: const [
    ApproverStats(id: 2, name: 'Bruno Lima', approved: 18, rejected: 2),
    ApproverStats(id: 7, name: 'Marina Costa', approved: 8, rejected: 1),
  ],
  alerts: const [
    ReportAlert(
      kind: AlertKind.devolucaoAtrasada,
      critical: true,
      title: 'VW Gol · XYZ9K88',
      message: 'Com Felipe Ribeiro: devolução era até 19/10/2026 18:00',
    ),
    ReportAlert(
      kind: AlertKind.seguro,
      critical: true,
      title: 'Fiat Uno · UNO2B22',
      message: 'Seguro vencido em 10/10/2026',
    ),
    ReportAlert(
      kind: AlertKind.revisao,
      critical: false,
      title: 'Fiat Strada · ABC1D23',
      message: 'Revisão em 420 km (aos 50000 km)',
    ),
    ReportAlert(
      kind: AlertKind.cnh,
      critical: false,
      title: 'Carlos Mendes',
      message: 'CNH vence em 05/11/2026',
    ),
    ReportAlert(
      kind: AlertKind.saidaSemAprovacao,
      critical: false,
      title: 'Ana Souza · Macaé',
      message: 'Sai 21/10/2026 08:00 e ainda não foi aprovado',
    ),
  ],
);

void main() {
  testWidgets('Relatórios desenham tudo sem estourar o layout', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    ReportController.instance
      ..days = 90
      ..report = sampleReport();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Instrument Sans'),
        home: const ReportsPage(loadOnOpen: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Precisa de atenção'), findsOneWidget);
    expect(find.text('Ver todos (5)'), findsOneWidget);
  });
}
