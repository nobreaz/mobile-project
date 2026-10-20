import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/json_reader.dart';

/// Campos que o solicitante preenche (RF 3.3.1 e 3.3.3).
///
/// - `POST /solicitacoes`: todos obrigatórios (`partial` = false).
/// - `PATCH /solicitacoes/{id}`: só os enviados mudam; os outros ficam `null`.
class RequestFields {
  const RequestFields({
    this.reason,
    this.destination,
    this.passengers,
    this.departure,
    this.returnDate,
    this.returnPeriod,
  });

  factory RequestFields.fromJson(
    Map<String, dynamic> json, {
    required bool partial,
  }) {
    final r = JsonReader(json);
    bool read(String key) => !partial || r.has(key);

    final fields = RequestFields(
      reason: read('reason') ? r.requiredText('reason', 'Motivo') : null,
      destination: read('destination')
          ? r.requiredText('destination', 'Destino')
          : null,
      passengers: read('passengers')
          ? r.integer('passengers', 'Passageiros', min: 1)
          : null,
      departure: read('departure') ? r.instant('departure', 'Saída') : null,
      returnDate: read('returnDate')
          ? r.requiredDate('returnDate', 'Data de retorno')
          : null,
      returnPeriod: read('returnPeriod')
          ? r.choice('returnPeriod', ReturnPeriod.values, 'Período de retorno')
          : null,
    );

    r.throwIfInvalid();
    return fields;
  }

  final String? reason;
  final String? destination;
  final int? passengers;

  /// Sempre em UTC.
  final DateTime? departure;

  /// Só o dia (sem horário).
  final DateTime? returnDate;
  final ReturnPeriod? returnPeriod;
}

/// Corpo de `POST /solicitacoes/{id}/aprovar`: o veículo escolhido (4.1.3).
int parseApproval(Map<String, dynamic> json) {
  final r = JsonReader(json);
  final vehicleId = r.integer('vehicleId', 'Veículo', min: 1);
  r.throwIfInvalid();
  return vehicleId!;
}

/// Corpo de `POST /solicitacoes/{id}/recusar`: justificativa obrigatória
/// (RN 4.7).
String parseRejection(Map<String, dynamic> json) {
  final r = JsonReader(json);
  final justification = r.requiredText('justification', 'Justificativa');
  r.throwIfInvalid();
  return justification;
}

/// Corpo da retirada (check-out) e da devolução (check-in):
/// quilometragem do painel e observação opcional (RF 3.3.5 e 3.3.6).
({int mileage, String? notes}) parseMileage(Map<String, dynamic> json) {
  final r = JsonReader(json);
  final mileage = r.integer('mileage', 'Quilometragem');
  final notes = r.optionalText('notes');
  r.throwIfInvalid();
  return (mileage: mileage!, notes: notes);
}
