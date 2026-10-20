import 'package:flutter/material.dart';
import 'package:project/core/controllers/loadable.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/services/api_client.dart';

/// A frota, vinda da API (`/veiculos`).
///
/// Todos os perfis leem (o Padrão precisa ver o carro alocado a ele);
/// só o Administrador altera, e o servidor confere isso.
/// Status "Em uso" e km mudam sozinhos na retirada/devolução (servidor).
class VehicleController extends ChangeNotifier with Loadable {
  VehicleController._();
  static final VehicleController instance = VehicleController._();

  ApiClient get _api => ApiClient.instance;

  List<VehicleModel> _vehicles = [];

  /// Lista completa da frota (inativos por último).
  List<VehicleModel> get vehicles => List.unmodifiable(_vehicles);

  VehicleModel? byId(int id) {
    for (final v in _vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<void> load() => guardLoad(() async {
    final list = await _api.get('/veiculos') as List;
    _vehicles = [
      for (final json in list)
        VehicleModel.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// Apaga os dados ao sair da conta.
  void clear() {
    _vehicles = [];
    error = null;
    notifyListeners();
  }

  /// CREATE — cadastra um novo veículo (requisito 3.2.1).
  Future<VehicleModel> addVehicle(Map<String, dynamic> data) async {
    final created = VehicleModel.fromJson(await _api.post('/veiculos', data));
    _vehicles = [..._vehicles, created];
    notifyListeners();
    return created;
  }

  /// UPDATE — altera só os campos enviados (requisitos 3.2.3 e 3.2.4).
  /// Devolve quantas reservas aprovadas voltaram para Pendente porque o
  /// veículo deixou de atendê-las (o servidor decide e notifica).
  Future<int> updateVehicle(int id, Map<String, dynamic> changes) async {
    final json =
        await _api.patch('/veiculos/$id', changes) as Map<String, dynamic>;
    final updated = VehicleModel.fromJson(json);
    _vehicles = [for (final v in _vehicles) v.id == id ? updated : v];
    notifyListeners();

    final released = (json['releasedRequestIds'] as List?)?.length ?? 0;
    if (released > 0) await RequestController.instance.load();
    return released;
  }

  /// Requisito 3.2.4: o veículo é desativado (status Inativo), nunca
  /// apagado, para preservar o histórico de solicitações que o usaram.
  Future<int> deactivateVehicle(int id) =>
      updateVehicle(id, {'status': VehicleStatus.inativo.name});

  /// Devolve um veículo inativo à frota.
  Future<int> reactivateVehicle(int id) =>
      updateVehicle(id, {'status': VehicleStatus.disponivel.name});
}
