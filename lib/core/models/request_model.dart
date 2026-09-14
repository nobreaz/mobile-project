import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

/// Status possíveis de uma solicitação de agendamento.
/// Alinhado à regra de negócio do documento (Pendente é o estado inicial).
enum RequestStatus { pendente, aprovada, recusada, cancelada }

extension RequestStatusX on RequestStatus {
  /// Texto exibido na interface.
  String get label {
    switch (this) {
      case RequestStatus.pendente:
        return 'Pendente';
      case RequestStatus.aprovada:
        return 'Aprovada';
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
      case RequestStatus.recusada:
        return AppColors.rejected;
      case RequestStatus.cancelada:
        return AppColors.canceled;
    }
  }
}

/// Representa uma solicitação de agendamento de veículo.
/// (Entidade "Solicitação de agendamento" do documento de requisitos.)
class RequestModel {
  final int id;
  final String reason;
  final String destination;
  final int passengers;
  final DateTime? departure;
  final DateTime? returnDate;
  RequestStatus status;

  RequestModel({
    required this.id,
    required this.reason,
    required this.destination,
    required this.passengers,
    this.departure,
    this.returnDate,
    this.status = RequestStatus.pendente,
  });
}
