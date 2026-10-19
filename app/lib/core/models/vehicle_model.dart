import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart';
import 'package:project/core/theme/app_colors.dart';

// Modelos e regras vêm do pacote compartilhado com a API.
export 'package:frota_core/frota_core.dart'
    show
        VehicleStatus,
        VehicleStatusX,
        VehicleType,
        VehicleTypeX,
        ExpiryStatus,
        expiryStatusOf,
        VehicleModel;

/// Cores e ícones do veículo (só existem no app).
extension VehicleStatusUi on VehicleStatus {
  Color get color {
    switch (this) {
      case VehicleStatus.disponivel:
        return AppColors.approved;
      case VehicleStatus.emUso:
        return AppColors.primary;
      case VehicleStatus.emManutencao:
        return AppColors.canceled;
      case VehicleStatus.inativo:
        return AppColors.rejected;
    }
  }
}

extension VehicleTypeUi on VehicleType {
  IconData get icon {
    switch (this) {
      case VehicleType.passeio:
        return Icons.directions_car;
      case VehicleType.utilitario:
        return Icons.local_shipping;
      case VehicleType.van:
        return Icons.airport_shuttle;
    }
  }
}

extension ExpiryStatusUi on ExpiryStatus {
  Color get color {
    switch (this) {
      case ExpiryStatus.valido:
        return AppColors.approved;
      case ExpiryStatus.vencendo:
        return AppColors.canceled;
      case ExpiryStatus.vencido:
        return AppColors.rejected;
      case ExpiryStatus.naoInformado:
        return AppColors.textMuted;
    }
  }
}
