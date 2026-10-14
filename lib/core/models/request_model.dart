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

/// Período do dia em que o veículo será devolvido.
enum ReturnPeriod { manha, tarde }

extension ReturnPeriodX on ReturnPeriod {
  String get label {
    switch (this) {
      case ReturnPeriod.manha:
        return 'Manhã';
      case ReturnPeriod.tarde:
        return 'Tarde';
    }
  }

  /// Horário limite de devolução de cada período.
  int get endHour {
    switch (this) {
      case ReturnPeriod.manha:
        return 12;
      case ReturnPeriod.tarde:
        return 18;
    }
  }

  String get description => 'até ${endHour}h';
}

/// Representa uma solicitação de agendamento de veículo.
/// (Entidade "Solicitação de agendamento" — seção 5.3 do documento.)
class RequestModel {
  final int id;

  /// Usuário que abriu a solicitação (id + nome).
  final int requesterId;
  final String requester;

  // Campos editáveis antes do check-out.
  String reason;
  String destination;
  int passengers;
  DateTime? departure;
  DateTime? returnDate;
  ReturnPeriod? returnPeriod;

  RequestStatus status;

  /// Veículo alocado pelo aprovador (item 5.3.4 / regra 4.1.3).
  int? vehicleId;

  /// Justificativa obrigatória em caso de recusa (regra 4.7).
  String? rejectionReason;

  /// Quilometragem de saída e de retorno (item 5.3.5 / regra 4.8).
  int? departureMileage;
  int? returnMileage;

  /// Momentos reais de retirada e devolução.
  DateTime? checkOutAt;
  DateTime? checkInAt;

  /// Observações registradas na retirada e na devolução.
  String? checkOutNotes;
  String? checkInNotes;

  RequestModel({
    required this.id,
    required this.reason,
    required this.destination,
    required this.passengers,
    this.requesterId = 1,
    this.requester = 'Nome Sobrenome',
    this.departure,
    this.returnDate,
    this.returnPeriod,
    this.status = RequestStatus.pendente,
    this.vehicleId,
    this.rejectionReason,
    this.departureMileage,
    this.returnMileage,
    this.checkOutAt,
    this.checkInAt,
    this.checkOutNotes,
    this.checkInNotes,
  });

  /// Prazo exato de devolução: data de retorno + horário do período.
  DateTime? get returnDeadline {
    final date = returnDate;
    if (date == null) return null;
    final hour = (returnPeriod ?? ReturnPeriod.tarde).endHour;
    return DateTime(date.year, date.month, date.day, hour);
  }

  /// Pode ser editada? Somente antes do check-out.
  bool get canEdit =>
      status == RequestStatus.pendente || status == RequestStatus.aprovada;

  /// Data de saída passou e o veículo não foi retirado.
  bool get isCheckOutLate =>
      status == RequestStatus.aprovada &&
      departure != null &&
      departure!.isBefore(DateTime.now());

  /// Prazo de retorno passou e o veículo continua em uso.
  bool get isReturnLate =>
      status == RequestStatus.emUso &&
      returnDeadline != null &&
      returnDeadline!.isBefore(DateTime.now());

  /// Viagem finalizada, mas devolvida depois do prazo.
  bool get wasReturnedLate {
    final deadline = returnDeadline;
    final at = checkInAt;
    return status == RequestStatus.finalizada &&
        deadline != null &&
        at != null &&
        at.isAfter(deadline);
  }

  /// Distância percorrida na viagem, quando já finalizada.
  int? get distanceTravelled {
    if (departureMileage == null || returnMileage == null) return null;
    return returnMileage! - departureMileage!;
  }
}
