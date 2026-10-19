import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/theme/app_colors.dart';

// Modelos e regras vêm do pacote compartilhado com a API.
export 'package:frota_core/frota_core.dart'
    show
        RequestStatus,
        RequestStatusX,
        ReturnPeriod,
        ReturnPeriodX,
        periodsOverlap,
        RequestModel;

/// Cor de cada status (só existe no app).
extension RequestStatusUi on RequestStatus {
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
