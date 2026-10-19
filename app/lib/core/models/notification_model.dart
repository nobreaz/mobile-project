import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/theme/app_colors.dart';

// Modelos e regras vêm do pacote compartilhado com a API.
export 'package:frota_core/frota_core.dart'
    show NotificationType, NotificationTypeX, AppNotification;

/// Cor e ícone de cada tipo de notificação (só existem no app).
extension NotificationTypeUi on NotificationType {
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
