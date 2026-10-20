import 'package:frota_core/frota_core.dart';
import 'package:test/test.dart';

void main() {
  group('periodsOverlap (regras 4.3 e 4.4)', () {
    final d = DateTime(2026, 11, 10);
    DateTime at(int h) => DateTime(d.year, d.month, d.day, h);

    test('intervalos que se cruzam conflitam', () {
      expect(periodsOverlap(at(8), at(12), at(10), at(14)), isTrue);
    });

    test('um intervalo dentro do outro conflita', () {
      expect(periodsOverlap(at(8), at(18), at(10), at(12)), isTrue);
    });

    test('encostar não conflita (devolve 12h, outro sai 12h)', () {
      expect(periodsOverlap(at(8), at(12), at(12), at(18)), isFalse);
    });

    test('intervalos separados não conflitam', () {
      expect(periodsOverlap(at(8), at(10), at(13), at(18)), isFalse);
    });
  });

  group('RequestModel.returnDeadline', () {
    test('manhã vence às 12h e tarde às 18h', () {
      RequestModel req(ReturnPeriod p) => RequestModel(
        id: 1,
        reason: 'r',
        destination: 'd',
        passengers: 1,
        returnDate: DateTime(2026, 11, 10),
        returnPeriod: p,
      );

      expect(
        req(ReturnPeriod.manha).returnDeadline,
        DateTime(2026, 11, 10, 12),
      );
      expect(
        req(ReturnPeriod.tarde).returnDeadline,
        DateTime(2026, 11, 10, 18),
      );
    });
  });

  group('RequestStatus', () {
    test('ativos para o usuário: pendente, aprovada e em uso (4.4)', () {
      expect(RequestStatus.values.where((s) => s.isActive), [
        RequestStatus.pendente,
        RequestStatus.aprovada,
        RequestStatus.emUso,
      ]);
    });

    test('pendente não prende veículo (decisão sobre a 4.5)', () {
      expect(RequestStatus.pendente.holdsVehicle, isFalse);
      expect(RequestStatus.aprovada.holdsVehicle, isTrue);
    });
  });

  group('expiryStatusOf (5.1.5)', () {
    final today = DateTime(2026, 10, 19);

    test('classifica vencido, vencendo, válido e não informado', () {
      expect(expiryStatusOf(null, today: today), ExpiryStatus.naoInformado);
      expect(
        expiryStatusOf(DateTime(2026, 10, 18), today: today),
        ExpiryStatus.vencido,
      );
      expect(
        expiryStatusOf(DateTime(2026, 11, 18), today: today),
        ExpiryStatus.vencendo,
      );
      expect(
        expiryStatusOf(DateTime(2026, 11, 19), today: today),
        ExpiryStatus.valido,
      );
    });
  });

  group('RequestModel JSON e decisão', () {
    RequestModel sample() => RequestModel(
      id: 5,
      requesterId: 3,
      requester: 'Ana',
      reason: 'Visita',
      destination: 'Macaé',
      passengers: 2,
      departure: DateTime(2026, 11, 10, 8),
      returnDate: DateTime(2026, 11, 10),
      returnPeriod: ReturnPeriod.tarde,
      status: RequestStatus.aprovada,
      vehicleId: 1,
    );

    test('ida e volta preserva os dados (instantes em UTC)', () {
      final r = sample()..recordDecision(approverId: 2, approverName: 'Bruno');
      final json = r.toJson();

      expect(json['returnDate'], '2026-11-10');
      expect(json['departure'], endsWith('Z'));
      expect(json['approverName'], 'Bruno');

      final copy = RequestModel.fromJson(json);
      expect(copy.departure, DateTime(2026, 11, 10, 8));
      expect(copy.returnDeadline, DateTime(2026, 11, 10, 18));
      expect(copy.toJson(), json);
    });

    test('voltar para pendente apaga a decisão', () {
      final r = sample()
        ..recordDecision(approverId: 2, approverName: 'Bruno')
        ..clearDecision();
      expect([r.approverId, r.approverName, r.decidedAt], [null, null, null]);
    });

    test('aprovadas incluem em uso e finalizadas', () {
      expect(
        RequestStatus.values.where((s) => (sample()..status = s).wasApproved),
        [RequestStatus.aprovada, RequestStatus.emUso, RequestStatus.finalizada],
      );
    });
  });

  group('UserModel JSON', () {
    test('ida e volta preserva os dados (validade da CNH só com o dia)', () {
      final original = UserModel(
        id: 3,
        name: 'Carlos Mendes',
        email: 'carlos@empresa.com',
        role: 'Analista',
        department: 'Logística',
        cnhNumber: '123',
        cnhExpiry: DateTime(2027, 1, 5),
        profile: UserProfile.aprovador,
        active: false,
      );

      final json = original.toJson();
      expect(json['cnhExpiry'], '2027-01-05');
      expect(json['profile'], 'aprovador');

      final copy = UserModel.fromJson(json);
      expect(copy.toJson(), json);
    });
  });

  group('Perfis (segregação de funções)', () {
    test('cada função pertence a um único perfil', () {
      expect(UserProfile.values.where((p) => p.canRequest), [
        UserProfile.padrao,
      ]);
      expect(UserProfile.values.where((p) => p.canApprove), [
        UserProfile.aprovador,
      ]);
      expect(UserProfile.values.where((p) => p.canManageRegistry), [
        UserProfile.administrador,
      ]);
    });

    test('aprovador com CNH válida ainda assim não solicita', () {
      final approver = UserModel(
        id: 1,
        name: 'A',
        email: 'a@b.com',
        role: 'r',
        department: 'd',
        cnhNumber: '1',
        cnhExpiry: DateTime.now().add(const Duration(days: 365)),
        profile: UserProfile.aprovador,
      );
      expect(approver.hasValidCnh, isTrue);
      expect(approver.canRequestVehicle, isFalse);
    });
  });

  group('PasswordRules (6.2)', () {
    test('exige 6 caracteres, 1 número e 1 especial', () {
      expect(const PasswordRules('abc12!').isValid, isTrue);
      expect(const PasswordRules('ab1!').isValid, isFalse);
      expect(const PasswordRules('abcdef!').isValid, isFalse);
      expect(const PasswordRules('abcde1').isValid, isFalse);
    });
  });

  test('veículo em manutenção ou inativo não é agendável (4.6)', () {
    expect(VehicleStatus.values.where((s) => s.canBeScheduled), [
      VehicleStatus.disponivel,
      VehicleStatus.emUso,
    ]);
  });

  test('VehicleModel e AppNotification vão e voltam em JSON', () {
    final v = VehicleModel(
      id: 3,
      plate: 'ABC1D23',
      chassis: '9BW',
      model: 'Gol',
      color: 'Branco',
      year: 2022,
      seats: 5,
      mileage: 1000,
      type: VehicleType.utilitario,
      status: VehicleStatus.emManutencao,
      licensingExpiry: DateTime(2027, 3, 31),
      insuranceExpiry: DateTime(2027, 6, 10),
    );
    final json = v.toJson();
    expect(json['licensingExpiry'], '2027-03-31');
    expect(VehicleModel.fromJson(json).toJson(), json);

    final n = AppNotification(
      id: 1,
      userId: 2,
      requestId: 3,
      type: NotificationType.approved,
      destination: 'Macaé',
      message: 'ok',
      createdAt: DateTime.utc(2026, 11, 10, 11),
    );
    expect(AppNotification.fromJson(n.toJson()).toJson(), n.toJson());
  });

  group('Relatórios', () {
    final today = DateTime(2026, 10, 20);
    VehicleModel car({
      VehicleStatus status = VehicleStatus.disponivel,
      int? nextService,
      DateTime? licensing,
    }) => VehicleModel(
      id: 1,
      plate: 'ABC1D23',
      chassis: '9BW',
      model: 'Gol',
      color: 'Branco',
      year: 2022,
      seats: 5,
      mileage: 10000,
      status: status,
      licensingExpiry: licensing ?? DateTime(2027, 3, 31),
      insuranceExpiry: DateTime(2026, 11, 2),
      nextServiceMileage: nextService,
    );

    test('revisão: vencida, vencendo (até 1.000 km), válida', () {
      expect(serviceStatusOf(10000, null), ExpiryStatus.naoInformado);
      expect(serviceStatusOf(10000, 10000), ExpiryStatus.vencido);
      expect(serviceStatusOf(10000, 11000), ExpiryStatus.vencendo);
      expect(serviceStatusOf(10000, 11001), ExpiryStatus.valido);
    });

    test('alertas do veículo: documentos, revisão e manutenção', () {
      final alerts = vehicleAlerts(
        car(
          status: VehicleStatus.emManutencao,
          nextService: 9500,
          licensing: DateTime(2026, 10, 1),
        ),
        today: today,
      );
      expect(alerts.map((a) => (a.kind, a.critical)), [
        (AlertKind.licenciamento, true),
        (AlertKind.seguro, false),
        (AlertKind.revisao, true),
        (AlertKind.manutencao, false),
      ]);
      expect(alerts[1].message, 'Seguro vence em 02/11/2026');
    });

    test('veículo inativo não gera alerta', () {
      expect(
        vehicleAlerts(car(status: VehicleStatus.inativo), today: today),
        isEmpty,
      );
    });

    test('CNH: só de quem solicita (Padrão ativo)', () {
      UserModel u(UserProfile p, {bool active = true}) => UserModel(
        id: 1,
        name: 'Ana',
        email: 'a@b.com',
        role: 'r',
        department: 'd',
        profile: p,
        active: active,
      );
      expect(driverAlert(u(UserProfile.padrao))?.kind, AlertKind.cnh);
      expect(driverAlert(u(UserProfile.aprovador)), isNull);
      expect(driverAlert(u(UserProfile.padrao, active: false)), isNull);
    });

    test('FleetReport vai e volta em JSON e calcula as taxas', () {
      final report = FleetReport(
        days: 30,
        granularity: TrendGranularity.week,
        trips: 4,
        finishedTrips: 4,
        lateReturns: 1,
        requests: 6,
        statuses: {
          RequestStatus.finalizada: 4,
          RequestStatus.recusada: 1,
          RequestStatus.pendente: 1,
        },
        trend: [TrendPoint(start: DateTime(2026, 10, 12), trips: 4)],
        users: const [
          RankingEntry(id: 3, label: 'Ana', detail: 'TI', trips: 4, km: 520),
        ],
        vehicles: const [RankingEntry(id: 1, label: 'Gol', trips: 0)],
        departments: const [RankingEntry(label: 'TI', trips: 4, km: 520)],
        approvers: const [
          ApproverStats(id: 2, name: 'Bruno', approved: 4, rejected: 1),
        ],
        alerts: vehicleAlerts(car(), today: today),
      );

      final json = report.toJson();
      expect(FleetReport.fromJson(json).toJson(), json);
      expect(report.approvalRate, 0.8);
      expect(report.onTimeRate, 0.75);
      expect(report.periodLabel, '30 dias');
      expect(
        FleetReport.fromJson({...json, 'days': 365}).periodLabel,
        '12 meses',
      );
    });
  });
}
