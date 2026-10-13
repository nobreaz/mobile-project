import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

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
  });
}
