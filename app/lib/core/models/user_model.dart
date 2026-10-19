import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/theme/app_colors.dart';

// Modelos e regras vêm do pacote compartilhado com a API.
export 'package:frota_core/frota_core.dart'
    show UserProfile, UserProfileX, CnhStatus, CnhStatusX, UserModel;

/// Cor e ícone da situação da CNH (só existem no app).
extension CnhStatusUi on CnhStatus {
  Color get color {
    switch (this) {
      case CnhStatus.valida:
        return AppColors.approved;
      case CnhStatus.vencendo:
        return AppColors.canceled;
      case CnhStatus.vencida:
        return AppColors.rejected;
      case CnhStatus.naoInformada:
        return AppColors.textMuted;
    }
  }

  IconData get icon {
    switch (this) {
      case CnhStatus.valida:
        return Icons.check_circle_outline;
      case CnhStatus.vencendo:
        return Icons.schedule;
      case CnhStatus.vencida:
        return Icons.error_outline;
      case CnhStatus.naoInformada:
        return Icons.help_outline;
    }
  }
}
