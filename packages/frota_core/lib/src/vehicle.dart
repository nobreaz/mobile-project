import 'user.dart' show formatDate;

/// Status operacional do veículo.
/// (Requisito 3.2.5 e entidade "Veículo" — item 5.1.3 do documento.)
///
/// O status reflete apenas o que está acontecendo AGORA com o veículo.
/// Reservas futuras não alteram o status: elas ficam na agenda
/// (solicitações aprovadas) e são verificadas na hora de alocar.
///
/// Ciclo típico:
/// Disponível → Em uso (check-out) → Disponível (check-in)
enum VehicleStatus { disponivel, emUso, emManutencao, inativo }

extension VehicleStatusX on VehicleStatus {
  String get label {
    switch (this) {
      case VehicleStatus.disponivel:
        return 'Disponível';
      case VehicleStatus.emUso:
        return 'Em uso';
      case VehicleStatus.emManutencao:
        return 'Em manutenção';
      case VehicleStatus.inativo:
        return 'Inativo';
    }
  }

  /// Em manutenção ou inativo não pode ser agendado (regra 4.6).
  bool get canBeScheduled =>
      this != VehicleStatus.emManutencao && this != VehicleStatus.inativo;
}

/// Categoria / tipo do veículo (item 5.1.4 do documento).
enum VehicleType { passeio, utilitario, van }

extension VehicleTypeX on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.passeio:
        return 'Passeio';
      case VehicleType.utilitario:
        return 'Utilitário';
      case VehicleType.van:
        return 'Van';
    }
  }
}

/// Situação de um documento com vencimento (licenciamento/IPVA, seguro).
enum ExpiryStatus { valido, vencendo, vencido, naoInformado }

/// Válido, vencendo (até 30 dias), vencido ou não informado.
/// [today] permite testar com uma data fixa.
ExpiryStatus expiryStatusOf(DateTime? expiry, {DateTime? today}) {
  if (expiry == null) return ExpiryStatus.naoInformado;
  final now = today ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(expiry.year, expiry.month, expiry.day);
  final days = end.difference(start).inDays;
  if (days < 0) return ExpiryStatus.vencido;
  if (days <= 30) return ExpiryStatus.vencendo;
  return ExpiryStatus.valido;
}

/// A partir de quantos km antes da revisão o veículo entra em alerta.
const serviceWarningKm = 1000;

/// Situação da revisão pela quilometragem: vencida (chegou ou passou da km
/// marcada), vencendo (faltam até [serviceWarningKm]), válida ou não
/// informada. Usa o mesmo enum dos documentos para ter as mesmas cores.
ExpiryStatus serviceStatusOf(int mileage, int? nextServiceMileage) {
  if (nextServiceMileage == null) return ExpiryStatus.naoInformado;
  final remaining = nextServiceMileage - mileage;
  if (remaining <= 0) return ExpiryStatus.vencido;
  if (remaining <= serviceWarningKm) return ExpiryStatus.vencendo;
  return ExpiryStatus.valido;
}

/// Representa um veículo da frota.
/// (Entidade "Veículo" — seção 5.1 do documento de requisitos.)
class VehicleModel {
  final int id;
  String plate;
  String chassis;
  String model;
  String color;
  int year;
  int seats;
  int mileage;
  VehicleType type;
  VehicleStatus status;

  /// Vencimentos do licenciamento/IPVA e do seguro (item 5.1.5).
  DateTime? licensingExpiry;
  DateTime? insuranceExpiry;

  /// Quilometragem em que a próxima revisão deve ser feita (opcional).
  int? nextServiceMileage;

  VehicleModel({
    required this.id,
    required this.plate,
    required this.chassis,
    required this.model,
    required this.color,
    required this.year,
    required this.seats,
    required this.mileage,
    this.type = VehicleType.passeio,
    this.status = VehicleStatus.disponivel,
    this.licensingExpiry,
    this.insuranceExpiry,
    this.nextServiceMileage,
  });

  /// Formato JSON trocado entre a API e o app.
  /// Vencimentos são só o dia (`AAAA-MM-DD`).
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.parse(v);
    }

    return VehicleModel(
      id: json['id'] as int,
      plate: json['plate'] as String,
      chassis: json['chassis'] as String,
      model: json['model'] as String,
      color: json['color'] as String,
      year: json['year'] as int,
      seats: json['seats'] as int,
      mileage: json['mileage'] as int,
      type: VehicleType.values.byName(json['type'] as String),
      status: VehicleStatus.values.byName(json['status'] as String),
      licensingExpiry: date('licensingExpiry'),
      insuranceExpiry: date('insuranceExpiry'),
      nextServiceMileage: json['nextServiceMileage'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plate': plate,
    'chassis': chassis,
    'model': model,
    'color': color,
    'year': year,
    'seats': seats,
    'mileage': mileage,
    'type': type.name,
    'status': status.name,
    'licensingExpiry': licensingExpiry == null
        ? null
        : formatDate(licensingExpiry!),
    'insuranceExpiry': insuranceExpiry == null
        ? null
        : formatDate(insuranceExpiry!),
    'nextServiceMileage': nextServiceMileage,
  };

  ExpiryStatus get licensingStatus => expiryStatusOf(licensingExpiry);
  ExpiryStatus get insuranceStatus => expiryStatusOf(insuranceExpiry);
  ExpiryStatus get serviceStatus =>
      serviceStatusOf(mileage, nextServiceMileage);
}
