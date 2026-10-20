import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart';

// Modelos e regras vêm do pacote compartilhado com a API.
export 'package:frota_core/frota_core.dart'
    show
        AlertKind,
        ApproverStats,
        FleetReport,
        RankingEntry,
        ReportAlert,
        TrendGranularity,
        TrendPoint;

/// Ícone de cada tipo de alerta (só existe no app).
extension AlertKindUi on AlertKind {
  IconData get icon {
    switch (this) {
      case AlertKind.licenciamento:
        return Icons.description_outlined;
      case AlertKind.seguro:
        return Icons.shield_outlined;
      case AlertKind.revisao:
        return Icons.build_outlined;
      case AlertKind.manutencao:
        return Icons.car_repair;
      case AlertKind.cnh:
        return Icons.badge_outlined;
      case AlertKind.devolucaoAtrasada:
        return Icons.assignment_late_outlined;
      case AlertKind.saidaSemAprovacao:
        return Icons.hourglass_top;
    }
  }
}
