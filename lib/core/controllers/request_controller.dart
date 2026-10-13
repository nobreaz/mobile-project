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
    ReturnPeriod? returnPeriod,
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
        returnPeriod: returnPeriod,
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
  /// NÃO altera o status do veículo: a reserva passa a existir apenas
  /// na agenda. O veículo continua disponível para outros períodos
  /// que não se sobreponham a este.
  void approveRequest(int id, int vehicleId) {
    final request = _requests.firstWhere((e) => e.id == id);
    request
      ..status = RequestStatus.aprovada
      ..vehicleId = vehicleId
      ..rejectionReason = null;

    notifyListeners();
  }

  /// Recusa a solicitação. A justificativa é obrigatória (regra 4.7).
  void rejectRequest(int id, String justification) {
    final request = _requests.firstWhere((e) => e.id == id);
    request
      ..status = RequestStatus.recusada
      ..rejectionReason = justification
      ..vehicleId = null;

    notifyListeners();
  }

  /// Menor quilometragem aceita no check-out: o odômetro atual do
  /// veículo alocado. Um odômetro nunca anda para trás.
  int? minimumCheckOutMileage(RequestModel request) =>
      vehicleOf(request)?.mileage;

  /// CHECK-OUT — retirada do veículo pelo colaborador.
  ///
  /// Solicitação: Aprovada → Em uso. Veículo: Disponível → Em uso.
  /// Retorna `false` se a km informada for menor que a atual do veículo.
  bool checkOut(int id, int departureMileage) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.aprovada) return false;

    final minimum = minimumCheckOutMileage(request);
    if (minimum != null && departureMileage < minimum) return false;

    request
      ..status = RequestStatus.emUso
      ..departureMileage = departureMileage
      ..checkOutAt = DateTime.now();

    if (request.vehicleId != null) {
      VehicleController.instance.updateStatus(
        request.vehicleId!,
        VehicleStatus.emUso,
      );
    }

    notifyListeners();
    return true;
  }

  /// CHECK-IN — devolução do veículo.
  ///
  /// Atualiza a km do veículo (regra 4.8) e o devolve como Disponível,
  /// mesmo que a devolução ocorra antes do fim do período.
  /// Solicitação: Em uso → Finalizada.
  /// Retorna `false` se a km de retorno for menor que a km de saída.
  bool checkIn(int id, int returnMileage) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.emUso) return false;

    final minimum = request.departureMileage;
    if (minimum != null && returnMileage < minimum) return false;

    request
      ..status = RequestStatus.finalizada
      ..returnMileage = returnMileage
      ..checkInAt = DateTime.now();

    if (request.vehicleId != null) {
      VehicleController.instance.updateMileage(
        request.vehicleId!,
        returnMileage,
      );
      VehicleController.instance.updateStatus(
        request.vehicleId!,
        VehicleStatus.disponivel,
      );
    }

    notifyListeners();
    return true;
  }

  /// Regra RN 4.1: filtra os veículos elegíveis e ordena por menor km.
  ///
  /// Filtro:
  /// - fora de manutenção e ativo;
  /// - lugares suficientes para os passageiros;
  /// - sem conflito de agenda no período solicitado (regra 4.3).
  List<VehicleModel> eligibleVehicles(RequestModel request) {
    final eligible = VehicleController.instance.vehicles
        .where(
          (v) =>
              v.status != VehicleStatus.emManutencao &&
              v.status != VehicleStatus.inativo,
        )
        .where((v) => v.seats >= request.passengers)
        .where((v) => _isVehicleFree(v.id, request))
        .toList();

    eligible.sort((a, b) => a.mileage.compareTo(b.mileage));
    return eligible;
  }

  /// Verifica se o veículo está livre durante todo o intervalo da
  /// solicitação: da saída até o prazo de devolução (data + período).
  bool _isVehicleFree(int vehicleId, RequestModel request) {
    final start = request.departure;
    final end = request.returnDeadline;
    if (start == null || end == null) return false;

    for (final other in _requests) {
      if (other.id == request.id || other.vehicleId != vehicleId) continue;

      // Só reservas ativas ocupam a agenda.
      final isActive =
          other.status == RequestStatus.aprovada ||
          other.status == RequestStatus.emUso;
      if (!isActive) continue;

      final otherStart = other.status == RequestStatus.emUso
          ? (other.checkOutAt ?? other.departure)
          : other.departure;
      var otherEnd = other.returnDeadline;
      if (otherStart == null || otherEnd == null) return false;

      // Em uso e atrasado: continua ocupado até o check-in.
      if (other.status == RequestStatus.emUso &&
          otherEnd.isBefore(DateTime.now())) {
        otherEnd = DateTime(9999);
      }

      final overlaps = start.isBefore(otherEnd) && otherStart.isBefore(end);
      if (overlaps) return false;
    }

    return true;
  }

  /// Busca o veículo alocado a uma solicitação (ou nulo).
  VehicleModel? vehicleOf(RequestModel request) {
    if (request.vehicleId == null) return null;
    try {
      return VehicleController.instance.vehicles.firstWhere(
        (v) => v.id == request.vehicleId,
      );
    } catch (_) {
      return null;
    }
  }
}
