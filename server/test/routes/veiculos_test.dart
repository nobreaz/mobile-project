import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/api_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/veiculos/[id].dart' as veiculo_route;
import '../../routes/veiculos/index.dart' as veiculos_route;
import '../helpers.dart';

Matcher _apiError(int status) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', status));

void main() {
  late MockVeiculosRepository vehicles;
  late MockFrotaService frota;
  final admin = user(profile: UserProfile.administrador);
  final approver = user(id: 2, profile: UserProfile.aprovador);

  final body = {
    'plate': 'abc 1d23',
    'chassis': '9bwzzz377vt004251',
    'model': 'Gol',
    'color': 'Branco',
    'year': 2022,
    'seats': 5,
    'mileage': 1000,
    'licensingExpiry': '2027-03-31',
    'insuranceExpiry': '2027-06-10',
  };

  setUpAll(() => registerFallbackValue(vehicle()));

  setUp(() {
    vehicles = MockVeiculosRepository();
    frota = MockFrotaService();
  });

  test('GET /veiculos: qualquer perfil consulta a frota', () async {
    when(() => vehicles.list()).thenAnswer((_) async => [vehicle()]);

    final response = await veiculos_route.onRequest(
      contextFor(
        jsonRequest('GET', '/veiculos'),
        me: user(),
        vehicles: vehicles,
      ),
    );

    final list = await response.json() as List<dynamic>;
    expect(list.single, containsPair('licensingExpiry', '2027-03-31'));
  });

  test('POST /veiculos: administrador cadastra; placa normalizada', () async {
    when(
      () => frota.createVehicle(any()),
    ).thenAnswer((i) async => i.positionalArguments.first as VehicleModel);

    final response = await veiculos_route.onRequest(
      contextFor(
        jsonRequest('POST', '/veiculos', body),
        me: admin,
        frota: frota,
      ),
    );

    expect(response.statusCode, 201);
    final json = await response.json() as Map<String, dynamic>;
    expect(json['plate'], 'ABC1D23');
    expect(json['status'], 'disponivel');
  });

  test('POST /veiculos: aprovador não cadastra → 403', () {
    expect(
      () => veiculos_route.onRequest(
        contextFor(
          jsonRequest('POST', '/veiculos', body),
          me: approver,
          frota: frota,
        ),
      ),
      _apiError(403),
    );
  });

  test('POST /veiculos: status "emUso" e campos faltando → 400', () {
    expect(
      () => veiculos_route.onRequest(
        contextFor(
          jsonRequest('POST', '/veiculos', {'plate': 'X', 'status': 'emUso'}),
          me: admin,
          frota: frota,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.fields?.keys,
          'campos',
          containsAll(['status', 'chassis', 'seats', 'licensingExpiry']),
        ),
      ),
    );
  });

  test('PATCH /veiculos/{id}: devolve as reservas liberadas', () async {
    when(
      () => frota.updateVehicle(7, {'status': 'emManutencao'}),
    ).thenAnswer(
      (_) async => (vehicle: vehicle(id: 7), releasedRequestIds: [4, 5]),
    );

    final response = await veiculo_route.onRequest(
      contextFor(
        jsonRequest('PATCH', '/veiculos/7', {'status': 'emManutencao'}),
        me: admin,
        frota: frota,
      ),
      '7',
    );

    expect(await response.json(), containsPair('releasedRequestIds', [4, 5]));
  });

  test('GET /veiculos/abc → 404', () {
    expect(
      () => veiculo_route.onRequest(
        contextFor(jsonRequest('GET', '/veiculos/abc'), me: admin),
        'abc',
      ),
      _apiError(404),
    );
  });
}
