import 'package:flutter/material.dart';
import 'package:project/core/models/vehicle_model.dart';

/// Armazena a frota em memória enquanto o app está aberto.
///
/// Mesmo padrão do AppController e do RequestController:
/// singleton + ChangeNotifier. Quando o Firebase entrar,
/// basta trocar o miolo desta classe — as telas não mudam.
class VehicleController extends ChangeNotifier {
  VehicleController._();
  static final VehicleController instance = VehicleController._();

  final List<VehicleModel> _vehicles = [
    // Dados de exemplo para visualizar a tela (remover quando houver backend).
    VehicleModel(
      id: 1,
      plate: 'ABC-1D23',
      chassis: '9BWZZZ377VT004251',
      model: 'Toyota Corolla',
      color: 'Prata',
      year: 2022,
      seats: 5,
      mileage: 42500,
    ),
    VehicleModel(
      id: 2,
      plate: 'XYZ-4E56',
      chassis: '9BWZZZ377VT004252',
      model: 'Fiat Fiorino',
      color: 'Branco',
      year: 2020,
      seats: 2,
      mileage: 87300,
      type: VehicleType.utilitario,
      status: VehicleStatus.emManutencao,
    ),
  ];

  int _nextId = 3;

  /// Lista completa da frota.
  List<VehicleModel> get vehicles => List.unmodifiable(_vehicles);

  /// CREATE — cadastra um novo veículo (requisito 3.2.1).
  void addVehicle({
    required String plate,
    required String chassis,
    required String model,
    required String color,
    required int year,
    required int seats,
    required int mileage,
    VehicleType type = VehicleType.passeio,
    VehicleStatus status = VehicleStatus.disponivel,
  }) {
    _vehicles.add(
      VehicleModel(
        id: _nextId++,
        plate: plate,
        chassis: chassis,
        model: model,
        color: color,
        year: year,
        seats: seats,
        mileage: mileage,
        type: type,
        status: status,
      ),
    );
    notifyListeners();
  }

  /// UPDATE — altera as informações de um veículo (requisito 3.2.3).
  void updateVehicle(
    int id, {
    required String plate,
    required String chassis,
    required String model,
    required String color,
    required int year,
    required int seats,
    required int mileage,
    required VehicleType type,
    required VehicleStatus status,
  }) {
    final vehicle = _vehicles.firstWhere((v) => v.id == id);
    vehicle
      ..plate = plate
      ..chassis = chassis
      ..model = model
      ..color = color
      ..year = year
      ..seats = seats
      ..mileage = mileage
      ..type = type
      ..status = status;
    notifyListeners();
  }

  /// Altera apenas o status operacional de um veículo.
  ///
  /// Usado quando uma solicitação é aprovada (o veículo passa a
  /// "Em uso") ou quando ele é liberado de volta para a frota.
  void updateStatus(int id, VehicleStatus status) {
    final vehicle = _vehicles.firstWhere((v) => v.id == id);
    vehicle.status = status;
    notifyListeners();
  }

  /// Atualiza a quilometragem do veículo ao final de cada uso,
  /// a partir da km de retorno informada no check-in (regra 4.8).
  void updateMileage(int id, int mileage) {
    final vehicle = _vehicles.firstWhere((v) => v.id == id);
    vehicle.mileage = mileage;
    notifyListeners();
  }

  /// DELETE — remove um veículo da frota (requisito 3.2.4).
  void removeVehicle(int id) {
    _vehicles.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}
