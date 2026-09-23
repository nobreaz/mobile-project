import 'package:flutter/material.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';

/// Armazena as solicitações em memória enquanto o app está aberto.
///
/// Segue o mesmo padrão do AppController: singleton + ChangeNotifier.
/// Quando houver backend (Firebase), esta classe será o ponto único
/// a ser trocado por chamadas reais, sem mexer nas telas.
class RequestController extends ChangeNotifier {
  RequestController._();
  static final RequestController instance = RequestController._();

  final List<RequestModel> _requests = [];
  int _nextId = 1;

  /// Todas as solicitações, da mais recente para a mais antiga.
  List<RequestModel> get requests => List.unmodifiable(_requests.reversed);

  /// Apenas as solicitações aguardando decisão do aprovador.
  List<RequestModel> get pendingRequests => List.unmodifiable(
        _requests.reversed.where((r) => r.status == RequestStatus.pendente),
      );

  /// Cria uma nova solicitação (status inicial: Pendente) e avisa as telas.
  void addRequest({
    required String reason,
    required String destination,
    required int passengers,
    DateTime? departure,
    DateTime? returnDate,
    String requester = 'Nome Sobrenome',
  }) {
    _requests.add(
      RequestModel(
        id: _nextId++,
        reason: reason,
        destination: destination,
        passengers: passengers,
        departure: departure,
        returnDate: returnDate,
        requester: requester,
      ),
    );
    notifyListeners();
  }

  /// Cancela uma solicitação (somente enquanto estiver Pendente).
  void cancelRequest(int id) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status == RequestStatus.pendente) {
      request.status = RequestStatus.cancelada;
      notifyListeners();
    }
  }

  /// Aprova a solicitação e aloca o veículo escolhido pelo aprovador.
  /// (Requisito 3.3.4 e regra 4.1.3 do documento.)
  ///
  /// O veículo passa a "Reservado": sai da lista de disponíveis, mas
  /// ainda não está rodando. Só vira "Em uso" no check-out.
  void approveRequest(int id, int vehicleId) {
    final request = _requests.firstWhere((e) => e.id == id);
    request
      ..status = RequestStatus.aprovada
      ..vehicleId = vehicleId
      ..rejectionReason = null;

    VehicleController.instance.updateStatus(vehicleId, VehicleStatus.reservado);

    notifyListeners();
  }

  /// Recusa a solicitação. A justificativa é obrigatória (regra 4.7).
  /// Se já havia um veículo alocado, ele volta a ficar disponível.
  void rejectRequest(int id, String justification) {
    final request = _requests.firstWhere((e) => e.id == id);

    if (request.vehicleId != null) {
      VehicleController.instance
          .updateStatus(request.vehicleId!, VehicleStatus.disponivel);
    }

    request
      ..status = RequestStatus.recusada
      ..rejectionReason = justification
      ..vehicleId = null;

    notifyListeners();
  }

  /// CHECK-OUT — retirada do veículo pelo colaborador.
  ///
  /// Registra a quilometragem de saída e o momento da retirada.
  /// Solicitação: Aprovada → Em uso. Veículo: Reservado → Em uso.
  void checkOut(int id, int departureMileage) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.aprovada) return;

    request
      ..status = RequestStatus.emUso
      ..departureMileage = departureMileage
      ..checkOutAt = DateTime.now();

    if (request.vehicleId != null) {
      VehicleController.instance
          .updateStatus(request.vehicleId!, VehicleStatus.emUso);
    }

    notifyListeners();
  }

  /// CHECK-IN — devolução do veículo.
  ///
  /// Registra a quilometragem de retorno, atualiza a km do veículo
  /// (regra 4.8) e devolve o carro à frota como Disponível.
  /// Solicitação: Em uso → Finalizada.
  void checkIn(int id, int returnMileage) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.emUso) return;

    request
      ..status = RequestStatus.finalizada
      ..returnMileage = returnMileage
      ..checkInAt = DateTime.now();

    if (request.vehicleId != null) {
      VehicleController.instance
          .updateMileage(request.vehicleId!, returnMileage);
      VehicleController.instance
          .updateStatus(request.vehicleId!, VehicleStatus.disponivel);
    }

    notifyListeners();
  }

  /// Aplica a regra RN 4.1: filtra os veículos elegíveis e
  /// ordena por menor quilometragem, equilibrando o desgaste da frota.
  ///
  /// Filtro: status Disponível + lugares suficientes para os passageiros.
  List<VehicleModel> eligibleVehicles(RequestModel request) {
    final eligible = VehicleController.instance.vehicles
        .where((v) => v.status == VehicleStatus.disponivel)
        .where((v) => v.seats >= request.passengers)
        .toList();

    eligible.sort((a, b) => a.mileage.compareTo(b.mileage));
    return eligible;
  }

  /// Busca o veículo alocado a uma solicitação (ou nulo).
  VehicleModel? vehicleOf(RequestModel request) {
    if (request.vehicleId == null) return null;
    try {
      return VehicleController.instance.vehicles
          .firstWhere((v) => v.id == request.vehicleId);
    } catch (_) {
      return null;
    }
  }
}
