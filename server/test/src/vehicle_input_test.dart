import 'package:frota_server/src/api_exception.dart';
import 'package:frota_server/src/vehicle_input.dart';
import 'package:test/test.dart';

void main() {
  final body = {
    'plate': 'ABC1D23',
    'chassis': '9BW',
    'model': 'Gol',
    'color': 'Branco',
    'year': 2022,
    'seats': 5,
    'mileage': 1000,
    'licensingExpiry': '2027-03-31',
    'insuranceExpiry': '2027-06-10',
  };

  test('km da próxima revisão é opcional no cadastro', () {
    expect(parseNewVehicle(body).nextServiceMileage, isNull);
    expect(
      parseNewVehicle({...body, 'nextServiceMileage': 10000})
          .nextServiceMileage,
      10000,
    );
  });

  test('PATCH com null apaga a revisão; texto é recusado', () {
    expect(parseVehicleUpdate({'nextServiceMileage': null}), {
      'proxima_revisao_km': null,
    });
    expect(
      () => parseVehicleUpdate({'nextServiceMileage': 'muito'}),
      throwsA(isA<ApiException>()),
    );
  });
}
