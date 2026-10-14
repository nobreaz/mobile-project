import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

/// Tipos de notificação enviados ao solicitante.
enum NotificationType { sent, approved, rejected, canceled, reverted }

extension NotificationTypeX on NotificationType {
  String get title {
    switch (this) {
      case NotificationType.sent:
        return 'Solicitação enviada';
      case NotificationType.approved:
        return 'Solicitação aprovada';
      case NotificationType.rejected:
        return 'Solicitação recusada';
      case NotificationType.canceled:
        return 'Solicitação cancelada';
      case NotificationType.reverted:
        return 'Voltou para aprovação';
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.sent:
        return AppColors.primary;
      case NotificationType.approved:
        return AppColors.approved;
      case NotificationType.rejected:
        return AppColors.rejected;
      case NotificationType.canceled:
        return AppColors.textMuted;
      case NotificationType.reverted:
        return AppColors.canceled;
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.sent:
        return Icons.send_outlined;
      case NotificationType.approved:
        return Icons.check_circle_outline;
      case NotificationType.rejected:
        return Icons.cancel_outlined;
      case NotificationType.canceled:
        return Icons.block;
      case NotificationType.reverted:
        return Icons.replay;
    }
  }
}

/// Notificação exibida dentro do app.
class AppNotification {
  final int id;
  final int userId; // destinatário
  final int requestId;
  final NotificationType type;
  final String destination;
  final String message;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.requestId,
    required this.type,
    required this.destination,
    required this.message,
    required this.createdAt,
    this.read = false,
  });
}
