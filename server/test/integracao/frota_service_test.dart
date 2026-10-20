// Testes de integração do FrotaService contra o PostgreSQL de verdade.
//
// Rodam DENTRO de uma transação que é sempre desfeita no final: nada fica
// gravado no banco (só os contadores de id avançam). Usam o DATABASE_URL do
// server/.env.
//
// Desligados por padrão. Para rodar, dentro de server/:
//   INTEGRACAO=1 dart test test/integracao          (bash)
//   $env:INTEGRACAO=1; dart test test/integracao    (PowerShell)
@Tags(['integracao'])
library;

import 'dart:io';

import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/config.dart';
import 'package:frota_server/src/frota_service.dart';
import 'package:frota_server/src/notificacoes_repository.dart';
import 'package:frota_server/src/request_input.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:frota_server/src/usuarios_repository.dart';
import 'package:frota_server/src/veiculos_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// Executa as "transações" do serviço como SAVEPOINTs dentro da transação
/// do teste: um erro desfaz só aquela operação, como em produção, e no fim
/// o teste desfaz tudo.
class _InsideTx implements SessionExecutor {
  _InsideTx(this._tx);

  final TxSession _tx;
  var _count = 0;

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
  }) async {
    final name = 'sp${_count++}';
    await _tx.execute('SAVEPOINT $name');
    try {
      final result = await fn(_tx);
      await _tx.execute('RELEASE SAVEPOINT $name');
      return result;
    } catch (_) {
      await _tx.execute('ROLLBACK TO SAVEPOINT $name');
      rethrow;
    }
  }

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
  }) => fn(_tx);

  @override
  Future<void> close({bool force = false}) async {}
}

class _Rollback implements Exception {}

/// Dados de um cenário, todos criados dentro da transação do teste.
class _World {
  _World(this.tx) : service = FrotaService(_InsideTx(tx));

  final TxSession tx;
  final FrotaService service;
  late final users = UsuariosRepository(tx);
  late final vehicles = VeiculosRepository(tx);
  late final requests = SolicitacoesRepository(tx);
  late final notifications = NotificacoesRepository(tx);

  late UserModel ana; // padrão
  late UserModel caio; // padrão
  late UserModel bruno; // aprovador
  late VehicleModel van; // 7 lugares, 5.000 km
  late VehicleModel uno; // 2 lugares, 900 km
  late VehicleModel gol; // 5 lugares, 3.000 km

  var _seq = 0;

  Future<UserModel> _user(String name, UserProfile profile) async {
    final email = 'teste.${name.toLowerCase()}.${_seq++}@integracao.local';
    final auth = await tx.execute(
      Sql.named(
        'INSERT INTO auth.users (id, email, aud, role) '
        "VALUES (gen_random_uuid(), @email, 'authenticated', 'authenticated') "
        'RETURNING id::text',
      ),
      parameters: {'email': email},
    );
    return users.insert(
      UserModel(
        id: 0,
        name: name,
        email: email,
        role: 'Teste',
        department: 'Teste',
        profile: profile,
        cnhNumber: profile == UserProfile.padrao ? '123' : null,
        cnhExpiry: DateTime.now().add(const Duration(days: 365)),
      ),
      authId: auth.single.first! as String,
    );
  }

  Future<VehicleModel> _vehicle(String plate, int seats, int km) =>
      vehicles.insert(
        VehicleModel(
          id: 0,
          plate: plate,
          chassis: 'CHASSI$plate',
          model: 'Modelo $plate',
          color: 'Branco',
          year: 2022,
          seats: seats,
          mileage: km,
          licensingExpiry: DateTime(2027),
          insuranceExpiry: DateTime(2027),
        ),
      );

  Future<void> seed() async {
    ana = await _user('Ana', UserProfile.padrao);
    caio = await _user('Caio', UserProfile.padrao);
    bruno = await _user('Bruno', UserProfile.aprovador);
    van = await _vehicle('TST9A01', 7, 5000);
    uno = await _vehicle('TST9A02', 2, 900);
    gol = await _vehicle('TST9A03', 5, 3000);
  }

  /// Daqui a [days] dias, saindo às 8h e voltando no mesmo dia à tarde
  /// (horário de Brasília = UTC−3).
  RequestFields trip({
    int days = 3,
    int passengers = 1,
    ReturnPeriod period = ReturnPeriod.tarde,
  }) {
    final now = DateTime.now().toUtc();
    final day = DateTime.utc(now.year, now.month, now.day + days);
    return RequestFields(
      reason: 'Visita técnica',
      destination: 'Macaé',
      passengers: passengers,
      departure: day.add(const Duration(hours: 11)), // 8h em Brasília
      returnDate: DateTime(day.year, day.month, day.day),
      returnPeriod: period,
    );
  }

  Future<List<NotificationType>> notificationTypes(UserModel u) async => [
    for (final n in await notifications.listFor(u.id)) n.type,
  ];
}

Matcher _apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  final enabled = Platform.environment['INTEGRACAO'] == '1';
  late Pool<void> db;

  setUpAll(() {
    if (enabled) db = Pool.withUrl(Config.fromEnvironment().databaseUrl);
  });
  tearDownAll(() async {
    if (enabled) await db.close();
  });

  /// Roda [body] numa transação desfeita no final.
  void scenario(String name, Future<void> Function(_World w) body) {
    test(
      name,
      skip: enabled ? null : 'defina INTEGRACAO=1 para rodar contra o banco',
      () async {
        try {
          await db.runTx((tx) async {
            final w = _World(tx);
            await w.seed();
            await body(w);
            throw _Rollback();
          });
        } on _Rollback {
          // esperado: tudo desfeito
        }
      },
    );
  }

  scenario('prazo de devolução é 12h/18h no horário de Brasília', (w) async {
    final deadline = await w.requests.deadline(
      DateTime(2026, 11, 10),
      ReturnPeriod.manha,
    );
    expect(deadline, DateTime.utc(2026, 11, 10, 15));
  });

  scenario('criar: pendente, notifica e bloqueia conflito (RN 4.4)', (
    w,
  ) async {
    final created = await w.service.createRequest(w.ana, w.trip());

    expect(created.status, RequestStatus.pendente);
    expect(created.requester, 'Ana');
    expect(await w.notificationTypes(w.ana), [NotificationType.sent]);

    // Mesma pessoa, mesmo período → 409. Outra pessoa pode.
    await expectLater(w.service.createRequest(w.ana, w.trip()), _apiError(409));
    await w.service.createRequest(w.caio, w.trip());

    // Mais passageiros que o maior veículo da frota → 400.
    await expectLater(
      w.service.createRequest(w.ana, w.trip(days: 5, passengers: 99)),
      _apiError(400),
    );
  });

  scenario('elegíveis por lotação e menor km; aprovar aloca (RN 4.1/4.3)', (
    w,
  ) async {
    final a = await w.service.createRequest(w.ana, w.trip(passengers: 3));
    final c = await w.service.createRequest(w.caio, w.trip(passengers: 3));

    final eligible = await w.service.eligibleVehicles(a.id);
    final mine = eligible.where((v) => v.plate.startsWith('TST9A'));
    expect(mine.map((v) => v.plate), ['TST9A03', 'TST9A01']); // gol, van

    // Uno tem 2 lugares → 409.
    await expectLater(
      w.service.approve(w.bruno, a.id, w.uno.id),
      _apiError(409),
    );

    final approved = await w.service.approve(w.bruno, a.id, w.gol.id);
    expect(approved.status, RequestStatus.aprovada);
    expect(approved.vehicleId, w.gol.id);
    expect(approved.approverName, 'Bruno');
    expect(await w.notificationTypes(w.ana), [
      NotificationType.approved,
      NotificationType.sent,
    ]);

    // O gol está ocupado no período: some dos elegíveis do Caio e não
    // pode ser alocado de novo.
    final forCaio = await w.service.eligibleVehicles(c.id);
    expect(forCaio.map((v) => v.id), isNot(contains(w.gol.id)));
    await expectLater(
      w.service.approve(w.bruno, c.id, w.gol.id),
      _apiError(409),
    );

    // Já decidida: não aprova nem recusa de novo.
    await expectLater(w.service.reject(w.bruno, a.id, 'x'), _apiError(409));
  });

  scenario('editar: motivo mantém aprovação; passageiros voltam p/ pendente', (
    w,
  ) async {
    final r = await w.service.createRequest(w.ana, w.trip());
    await w.service.approve(w.bruno, r.id, w.gol.id);

    final sameApproval = await w.service.updateRequest(
      w.ana,
      r.id,
      const RequestFields(reason: 'Reunião'),
    );
    expect(sameApproval.status, RequestStatus.aprovada);
    expect(sameApproval.reason, 'Reunião');

    final reverted = await w.service.updateRequest(
      w.ana,
      r.id,
      const RequestFields(passengers: 2),
    );
    expect(reverted.status, RequestStatus.pendente);
    expect(reverted.vehicleId, isNull);
    expect(reverted.approverId, isNull);
    expect(
      (await w.notificationTypes(w.ana)).first,
      NotificationType.reverted,
    );

    // Outra pessoa não edita.
    await expectLater(
      w.service.updateRequest(w.caio, r.id, const RequestFields()),
      _apiError(403),
    );
  });

  scenario('retirada e devolução atualizam km e status do veículo', (w) async {
    final r = await w.service.createRequest(w.ana, w.trip());
    await w.service.approve(w.bruno, r.id, w.gol.id);

    await expectLater(
      w.service.checkOut(w.ana, r.id, mileage: 2999),
      _apiError(400),
    );
    final out = await w.service.checkOut(
      w.ana,
      r.id,
      mileage: 3010,
      notes: '  ',
    );
    expect(out.status, RequestStatus.emUso);
    expect(out.departureMileage, 3010);
    expect((await w.vehicles.findById(w.gol.id))!.status, VehicleStatus.emUso);

    // Em uso: o Administrador não muda o status.
    await expectLater(
      w.service.updateVehicle(w.gol.id, {'status': 'emManutencao'}),
      _apiError(409),
    );
    // Não dá para cancelar nem editar depois da retirada.
    await expectLater(w.service.cancelRequest(w.ana, r.id), _apiError(409));

    await expectLater(
      w.service.checkIn(w.ana, r.id, mileage: 3000),
      _apiError(400),
    );
    final done = await w.service.checkIn(
      w.ana,
      r.id,
      mileage: 3170,
      notes: 'Tudo certo',
    );
    expect(done.status, RequestStatus.finalizada);
    expect(done.distanceTravelled, 160);
    expect(done.checkInNotes, 'Tudo certo');

    final gol = (await w.vehicles.findById(w.gol.id))!;
    expect(gol.status, VehicleStatus.disponivel);
    expect(gol.mileage, 3170);
  });

  scenario('veículo em manutenção ou com menos lugares libera reservas', (
    w,
  ) async {
    final a = await w.service.createRequest(w.ana, w.trip(passengers: 4));
    final c = await w.service.createRequest(w.caio, w.trip(days: 6));
    await w.service.approve(w.bruno, a.id, w.van.id);
    await w.service.approve(w.bruno, c.id, w.van.id);

    // 7 → 3 lugares: só a da Ana (4 passageiros) volta.
    final fewer = await w.service.updateVehicle(w.van.id, {'lugares': 3});
    expect(fewer.releasedRequestIds, [a.id]);
    expect(fewer.vehicle.seats, 3);

    // Manutenção: a do Caio também volta, e ele é avisado.
    final maintenance = await w.service.updateVehicle(w.van.id, {
      'status': 'emManutencao',
    });
    expect(maintenance.releasedRequestIds, [c.id]);
    expect(
      (await w.requests.findById(c.id))!.status,
      RequestStatus.pendente,
    );
    expect(
      (await w.notificationTypes(w.caio)).first,
      NotificationType.reverted,
    );
    expect(
      (await w.service.eligibleVehicles(c.id)).map((v) => v.id),
      isNot(contains(w.van.id)),
    );
  });

  scenario('cancelar e recusar', (w) async {
    final a = await w.service.createRequest(w.ana, w.trip());
    final canceled = await w.service.cancelRequest(w.ana, a.id);
    expect(canceled.status, RequestStatus.cancelada);

    // Cancelada não ocupa mais a agenda: pode pedir de novo no mesmo horário.
    final again = await w.service.createRequest(w.ana, w.trip());
    final rejected = await w.service.reject(w.bruno, again.id, 'Sem verba');
    expect(rejected.status, RequestStatus.recusada);
    expect(rejected.rejectionReason, 'Sem verba');
    expect(rejected.approverName, 'Bruno');

    await w.notifications.markAllRead(w.ana.id);
    final all = await w.notifications.listFor(w.ana.id);
    expect(all.every((n) => n.read), isTrue);
  });

  scenario('placa repetida vira erro de unicidade', (w) async {
    await expectLater(
      w.service.createVehicle(
        VehicleModel(
          id: 0,
          plate: w.gol.plate,
          chassis: 'OUTRO',
          model: 'X',
          color: 'Y',
          year: 2020,
          seats: 5,
          mileage: 0,
          licensingExpiry: DateTime(2027),
          insuranceExpiry: DateTime(2027),
        ),
      ),
      throwsA(
        isA<ServerException>().having(
          (e) => e.constraintName,
          'constraint',
          'veiculos_placa_key',
        ),
      ),
    );
  });
}
