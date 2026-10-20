import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/json_reader.dart';

/// Placa e chassi são guardados sem espaços e em maiúsculas,
/// para a restrição `unique` do banco pegar "abc-1d23" e "ABC-1D23".
String _code(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

int get _maxYear => DateTime.now().year + 1;

/// "Em uso" só vem do check-out e volta a "Disponível" no check-in.
void _rejectInUse(JsonReader r, VehicleStatus? status) {
  if (status == VehicleStatus.emUso) {
    r.errors['status'] =
        'O status "Em uso" é definido pela retirada (check-out).';
  }
}

/// Corpo de `POST /veiculos` (Administrador, RF 3.2.1).
VehicleModel parseNewVehicle(Map<String, dynamic> json) {
  final r = JsonReader(json);

  final status = r.has('status')
      ? r.choice('status', VehicleStatus.values, 'Status')
      : VehicleStatus.disponivel;
  _rejectInUse(r, status);

  final vehicle = VehicleModel(
    id: 0, // definido pelo banco
    plate: _code(r.requiredText('plate', 'Placa')),
    chassis: _code(r.requiredText('chassis', 'Chassi')),
    model: r.requiredText('model', 'Modelo'),
    color: r.requiredText('color', 'Cor'),
    year: r.integer('year', 'Ano', min: 1950, max: _maxYear) ?? 0,
    seats: r.integer('seats', 'Lugares', min: 1, max: 99) ?? 0,
    mileage: r.integer('mileage', 'Quilometragem') ?? 0,
    type: r.has('type')
        ? r.choice('type', VehicleType.values, 'Tipo') ?? VehicleType.passeio
        : VehicleType.passeio,
    status: status ?? VehicleStatus.disponivel,
    licensingExpiry: r.requiredDate(
      'licensingExpiry',
      'Vencimento do licenciamento',
    ),
    insuranceExpiry: r.requiredDate('insuranceExpiry', 'Vencimento do seguro'),
  );

  r.throwIfInvalid();
  return vehicle;
}

/// Corpo de `PATCH /veiculos/{id}` (Administrador, RF 3.2.3 e 3.2.4).
/// Só os campos enviados mudam. Devolve as alterações com os nomes das
/// colunas do banco. Desativar = `status: "inativo"`; reativar =
/// `status: "disponivel"`.
Map<String, Object?> parseVehicleUpdate(Map<String, dynamic> json) {
  final r = JsonReader(json);
  final changes = <String, Object?>{};

  if (r.has('plate')) {
    changes['placa'] = _code(r.requiredText('plate', 'Placa'));
  }
  if (r.has('chassis')) {
    changes['chassi'] = _code(r.requiredText('chassis', 'Chassi'));
  }
  if (r.has('model')) changes['modelo'] = r.requiredText('model', 'Modelo');
  if (r.has('color')) changes['cor'] = r.requiredText('color', 'Cor');
  if (r.has('year')) {
    changes['ano'] = r.integer('year', 'Ano', min: 1950, max: _maxYear);
  }
  if (r.has('seats')) {
    changes['lugares'] = r.integer('seats', 'Lugares', min: 1, max: 99);
  }
  if (r.has('mileage')) {
    changes['quilometragem'] = r.integer('mileage', 'Quilometragem');
  }
  if (r.has('type')) {
    changes['tipo'] = r.choice('type', VehicleType.values, 'Tipo')?.name;
  }
  if (r.has('status')) {
    final status = r.choice('status', VehicleStatus.values, 'Status');
    _rejectInUse(r, status);
    changes['status'] = status?.name;
  }
  if (r.has('licensingExpiry')) {
    changes['vencimento_licenciamento'] = r.requiredDate(
      'licensingExpiry',
      'Vencimento do licenciamento',
    );
  }
  if (r.has('insuranceExpiry')) {
    changes['vencimento_seguro'] = r.requiredDate(
      'insuranceExpiry',
      'Vencimento do seguro',
    );
  }
  r.throwIfInvalid();
  return changes;
}
