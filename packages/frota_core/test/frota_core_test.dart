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
}
