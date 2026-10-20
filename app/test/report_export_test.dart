import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/services/report_export.dart';

import 'reports_page_test.dart' show sampleReport;

final now = DateTime(2026, 10, 20, 21, 5);

List<VehicleModel> sampleVehicles() => [
  VehicleModel(
    id: 1,
    plate: 'ABC1D23',
    chassis: '9BW1',
    model: 'Fiat Strada',
    color: 'Branco',
    year: 2022,
    seats: 2,
    mileage: 49580,
    licensingExpiry: DateTime(2020, 3, 31), // vencido
    insuranceExpiry: DateTime(2030, 6, 10),
    nextServiceMileage: 50000,
  ),
  VehicleModel(
    id: 2,
    plate: 'XYZ9K88',
    chassis: '9BW2',
    model: 'VW Gol',
    color: 'Prata',
    year: 2021,
    seats: 5,
    mileage: 30100,
    status: VehicleStatus.emManutencao,
    licensingExpiry: DateTime(2030, 3, 31),
    insuranceExpiry: DateTime(2030, 6, 10),
  ),
];

RequestModel trip({
  required int id,
  required DateTime checkOut,
  DateTime? checkIn,
  RequestStatus status = RequestStatus.finalizada,
}) => RequestModel(
  id: id,
  requesterId: 3,
  requester: 'Felipe Ribeiro',
  reason: 'Visita',
  destination: 'Macaé',
  passengers: 1,
  departure: checkOut,
  returnDate: DateTime(checkOut.year, checkOut.month, checkOut.day),
  returnPeriod: ReturnPeriod.tarde,
  status: status,
  vehicleId: 1,
  departureMileage: 49000,
  returnMileage: checkIn == null ? null : 49120,
  checkOutAt: checkOut,
  checkInAt: checkIn,
);

List<RequestModel> sampleRequests() => [
  // Devolvida às 20h, prazo 18h → com atraso.
  trip(
    id: 1,
    checkOut: DateTime(2026, 10, 1, 8),
    checkIn: DateTime(2026, 10, 1, 20),
  ),
  trip(
    id: 2,
    checkOut: DateTime(2026, 10, 15, 8),
    checkIn: DateTime(2026, 10, 15, 12),
  ),
  // Fora do período (30 dias).
  trip(
    id: 3,
    checkOut: DateTime(2026, 8, 1, 8),
    checkIn: DateTime(2026, 8, 1, 12),
  ),
  RequestModel(
    id: 4,
    requesterId: 4,
    requester: 'Ana Souza',
    reason: 'Curso',
    destination: 'Rio das Ostras',
    passengers: 6,
    status: RequestStatus.recusada,
    rejectionReason: 'Sem veículo com 6 lugares; use a van na próxima semana',
    approverId: 2,
    approverName: 'Bruno Lima',
    decidedAt: DateTime(2026, 10, 10, 9, 30),
  ),
];

ExportTable table(String title) => reportTables(
  sampleReport(),
  vehicles: sampleVehicles(),
  requests: sampleRequests(),
  now: now,
).firstWhere((t) => t.title == title);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nome do arquivo tem período e data', () {
    expect(
      exportFileName(sampleReport(), now),
      'relatorio-frota-90-dias-2026-10-20.pdf',
    );
  });

  test('situação da frota: status, vencimentos e revisão', () {
    expect(table('Situação atual da frota').rows, [
      [
        'Fiat Strada',
        'ABC1D23',
        'Disponível',
        '49.580',
        '31/03/2020 (vencido)',
        '10/06/2030',
        'aos 50.000 km (faltam 420)',
      ],
      [
        'VW Gol',
        'XYZ9K88',
        'Em manutenção',
        '30.100',
        '31/03/2030',
        '10/06/2030',
        '—',
      ],
    ]);
  });

  test('histórico: só as retiradas no período, mais recente primeiro', () {
    // O relatório de exemplo é de 90 dias: a de agosto entra.
    final rows = table('Histórico de viagens').rows;
    expect(rows.map((r) => r.first), [
      '15/10 08:00',
      '01/10 08:00',
      '01/08 08:00',
    ]);
    expect(rows[0], [
      '15/10 08:00',
      '15/10 12:00',
      'Felipe Ribeiro',
      'Fiat Strada ABC1D23',
      'Macaé',
      '120',
      'No prazo',
    ]);
    expect(rows[1].last, 'Com atraso');
  });

  test('recusadas trazem quem recusou e a justificativa', () {
    expect(table('Solicitações recusadas').rows.single, [
      '10/10 09:30',
      'Ana Souza',
      'Rio das Ostras',
      'Bruno Lima',
      'Sem veículo com 6 lugares; use a van na próxima semana',
    ]);
  });

  test('PDF é gerado com a fonte do app', () async {
    final bytes = await buildReportPdf(
      sampleReport(),
      vehicles: sampleVehicles(),
      requests: sampleRequests(),
      now: now,
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(10000)); // fonte embutida
  });
}
