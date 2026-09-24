import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

/// Status possíveis de uma solicitação de agendamento.
///
/// Ciclo previsto na regra 4.2 do documento:
/// Pendente → Aprovada → Em uso → Finalizada
/// (ou, a partir de Pendente: Negada / Cancelada)
enum RequestStatus {
  pendente,
  aprovada,
  emUso,
  finalizada,
  recusada,
  cancelada,
}

extension RequestStatusX on RequestStatus {
  /// Texto exibido na interface.
  String get label {
    switch (this) {
      case RequestStatus.pendente:
        return 'Pendente';
      case RequestStatus.aprovada:
        return 'Aprovada';
      case RequestStatus.emUso:
        return 'Em uso';
      case RequestStatus.finalizada:
        return 'Finalizada';
      case RequestStatus.recusada:
        return 'Recusada';
      case RequestStatus.cancelada:
        return 'Cancelada';
    }
  }

  /// Cor associada ao status (reaproveita a paleta do app).
  Color get color {
    switch (this) {
      case RequestStatus.pendente:
        return AppColors.primary;
      case RequestStatus.aprovada:
        return AppColors.approved;
      case RequestStatus.emUso:
        return AppColors.primaryDark;
      case RequestStatus.finalizada:
        return AppColors.textMuted;
      case RequestStatus.recusada:
        return AppColors.rejected;
      case RequestStatus.cancelada:
        return AppColors.canceled;
    }
  }
}

/// Representa uma solicitação de agendamento de veículo.
/// (Entidade "Solicitação de agendamento" — seção 5.3 do documento.)
class RequestModel {
  final int id;

  /// Quem abriu a solicitação (item 5.3.1).
  /// Enquanto não há autenticação, recebe um valor padrão.
  final String requester;

  final String reason;
  final String destination;
  final int passengers;
  final DateTime? departure;
  final DateTime? returnDate;

  RequestStatus status;

  /// Veículo alocado pelo aprovador (item 5.3.4 / regra 4.1.3).
  int? vehicleId;

  /// Justificativa obrigatória em caso de recusa (regra 4.7).
  String? rejectionReason;

  /// Quilometragem registrada no check-out (retirada do veículo).
  /// Item 5.3.5 do documento.
  int? departureMileage;

  /// Quilometragem registrada no check-in (devolução do veículo).
  /// Alimenta a atualização da km do veículo — regra 4.8.
  int? returnMileage;

  /// Momento em que o veículo foi efetivamente retirado.
  DateTime? checkOutAt;

  /// Momento em que o veículo foi efetivamente devolvido.
  DateTime? checkInAt;

  RequestModel({
    required this.id,
    required this.reason,
    required this.destination,
    required this.passengers,
    this.requester = 'Nome Sobrenome',
    this.departure,
    this.returnDate,
    this.status = RequestStatus.pendente,
    this.vehicleId,
    this.rejectionReason,
    this.departureMileage,
    this.returnMileage,
    this.checkOutAt,
    this.checkInAt,
  });

  /// Indica se a reserva está atrasada: a data de saída já passou
  /// e o motorista ainda não realizou o check-out.
  bool get isCheckOutLate =>
      status == RequestStatus.aprovada &&
      departure != null &&
      departure!.isBefore(DateTime.now());

  /// Indica se a devolução está atrasada: a data de retorno já passou
  /// e o veículo continua em uso.
  bool get isReturnLate =>
      status == RequestStatus.emUso &&
      returnDate != null &&
      returnDate!.isBefore(DateTime.now());

  /// Distância percorrida na viagem, quando já finalizada.
  int? get distanceTravelled {
    if (departureMileage == null || returnMileage == null) return null;
    return returnMileage! - departureMileage!;
  }
}
