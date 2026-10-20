import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/request_input.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/solicitacoes/[id]/aprovar.dart' as aprovar;
import '../../routes/solicitacoes/[id]/devolucao.dart' as devolucao;
import '../../routes/solicitacoes/[id]/index.dart' as detalhe;
import '../../routes/solicitacoes/[id]/recusar.dart' as recusar;
import '../../routes/solicitacoes/[id]/veiculos.dart' as elegiveis;
import '../../routes/solicitacoes/index.dart' as solicitacoes;
import '../helpers.dart';

Matcher _apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late MockFrotaService frota;
  late MockSolicitacoesRepository requests;
  final ana = user(id: 3);
  final approver = user(id: 2, profile: UserProfile.aprovador);
  final admin = user(profile: UserProfile.administrador);

  final newRequest = {
    'reason': 'Visita',
    'destination': 'Macaé',
    'passengers': 2,
    'departure': '2026-11-10T11:00:00.000Z',
    'returnDate': '2026-11-10',
    'returnPeriod': 'tarde',
  };

  setUpAll(() {
    registerFallbackValue(user());
    registerFallbackValue(const RequestFields());
  });

  setUp(() {
    frota = MockFrotaService();
    requests = MockSolicitacoesRepository();
  });

  group('POST /solicitacoes', () {
    test('padrão cria → 201', () async {
      when(
        () => frota.createRequest(ana, any()),
      ).thenAnswer((_) async => request());

      final response = await solicitacoes.onRequest(
        contextFor(
          jsonRequest('POST', '/solicitacoes', newRequest),
          me: ana,
          frota: frota,
        ),
      );

      expect(response.statusCode, 201);
      final fields =
          verify(
                () => frota.createRequest(ana, captureAny()),
              ).captured.single
              as RequestFields;
      expect(fields.departure, DateTime.utc(2026, 11, 10, 11));
      expect(fields.returnPeriod, ReturnPeriod.tarde);
    });

    test('aprovador e administrador não solicitam → 403', () {
      for (final me in [approver, admin]) {
        expect(
          () => solicitacoes.onRequest(
            contextFor(
              jsonRequest('POST', '/solicitacoes', newRequest),
              me: me,
              frota: frota,
            ),
          ),
          _apiError(403),
        );
      }
    });

    test('saída sem fuso e campos faltando → 400', () {
      expect(
        () => solicitacoes.onRequest(
          contextFor(
            jsonRequest('POST', '/solicitacoes', {
              'departure': '2026-11-10T08:00:00',
              'passengers': 0,
            }),
            me: ana,
            frota: frota,
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fields?.keys,
            'campos',
            unorderedEquals([
              'reason',
              'destination',
              'passengers',
              'departure',
              'returnDate',
              'returnPeriod',
            ]),
          ),
        ),
      );
    });
  });

  group('GET /solicitacoes/{id}', () {
    test('padrão não vê a de outra pessoa → 404', () {
      when(
        () => requests.findById(1),
      ).thenAnswer((_) async => request(requesterId: 99));

      expect(
        () => detalhe.onRequest(
          contextFor(
            jsonRequest('GET', '/solicitacoes/1'),
            me: ana,
            requests: requests,
          ),
          '1',
        ),
        _apiError(404),
      );
    });

    test('aprovador vê qualquer uma', () async {
      when(
        () => requests.findById(1),
      ).thenAnswer((_) async => request(requesterId: 99));

      final response = await detalhe.onRequest(
        contextFor(
          jsonRequest('GET', '/solicitacoes/1'),
          me: approver,
          requests: requests,
        ),
        '1',
      );
      expect(await response.json(), containsPair('requesterId', 99));
    });
  });

  test('PATCH: só os campos enviados chegam ao serviço', () async {
    when(
      () => frota.updateRequest(ana, 1, any()),
    ).thenAnswer((_) async => request());

    await detalhe.onRequest(
      contextFor(
        jsonRequest('PATCH', '/solicitacoes/1', {'reason': 'Reunião'}),
        me: ana,
        frota: frota,
      ),
      '1',
    );

    final fields =
        verify(
              () => frota.updateRequest(ana, 1, captureAny()),
            ).captured.single
            as RequestFields;
    expect(fields.reason, 'Reunião');
    expect(fields.departure, isNull);
    expect(fields.passengers, isNull);
  });

  test('aprovar: só aprovador, com vehicleId', () async {
    when(
      () => frota.approve(approver, 1, 7),
    ).thenAnswer((_) async => request(status: RequestStatus.aprovada));

    final response = await aprovar.onRequest(
      contextFor(
        jsonRequest('POST', '/solicitacoes/1/aprovar', {'vehicleId': 7}),
        me: approver,
        frota: frota,
      ),
      '1',
    );
    expect(await response.json(), containsPair('status', 'aprovada'));

    expect(
      () => aprovar.onRequest(
        contextFor(
          jsonRequest('POST', '/solicitacoes/1/aprovar', {'vehicleId': 7}),
          me: ana,
          frota: frota,
        ),
        '1',
      ),
      _apiError(403),
    );
    expect(
      () => aprovar.onRequest(
        contextFor(
          jsonRequest('POST', '/solicitacoes/1/aprovar', <String, Object>{}),
          me: approver,
          frota: frota,
        ),
        '1',
      ),
      _apiError(400),
    );
  });

  test('recusar sem justificativa → 400 (RN 4.7)', () {
    expect(
      () => recusar.onRequest(
        contextFor(
          jsonRequest('POST', '/solicitacoes/1/recusar', {
            'justification': '  ',
          }),
          me: approver,
          frota: frota,
        ),
        '1',
      ),
      _apiError(400),
    );
  });

  test('devolução: km obrigatória; observação vazia vira null', () async {
    when(
      () => frota.checkIn(ana, 1, mileage: 1200),
    ).thenAnswer((_) async => request(status: RequestStatus.finalizada));

    await devolucao.onRequest(
      contextFor(
        jsonRequest('POST', '/solicitacoes/1/devolucao', {
          'mileage': 1200,
          'notes': ' ',
        }),
        me: ana,
        frota: frota,
      ),
      '1',
    );
    verify(() => frota.checkIn(ana, 1, mileage: 1200)).called(1);

    expect(
      () => devolucao.onRequest(
        contextFor(
          jsonRequest('POST', '/solicitacoes/1/devolucao', {'mileage': -5}),
          me: ana,
          frota: frota,
        ),
        '1',
      ),
      _apiError(400),
    );
  });

  test('veículos elegíveis: só aprovador', () async {
    when(
      () => frota.eligibleVehicles(1),
    ).thenAnswer((_) async => [vehicle()]);

    final response = await elegiveis.onRequest(
      contextFor(
        jsonRequest('GET', '/solicitacoes/1/veiculos'),
        me: approver,
        frota: frota,
      ),
      '1',
    );
    expect(await response.json(), hasLength(1));

    expect(
      () => elegiveis.onRequest(
        contextFor(
          jsonRequest('GET', '/solicitacoes/1/veiculos'),
          me: admin,
          frota: frota,
        ),
        '1',
      ),
      _apiError(403),
    );
  });
}
