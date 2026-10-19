import 'package:flutter/material.dart';
import 'package:project/core/controllers/notification_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/notification_model.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';

/// Armazena as solicitações em memória enquanto o app está aberto.
///
/// Mesmo padrão do AppController: singleton + ChangeNotifier.
/// Quando houver backend (Firebase), basta trocar o miolo desta classe.
class RequestController extends ChangeNotifier {
  RequestController._();
  static final RequestController instance = RequestController._();

  final List<RequestModel> _requests = _seed();
  int _nextId = 3;

  /// Solicitações de exemplo (remover quando houver backend).
  static List<RequestModel> _seed() {
    final now = DateTime.now();
    final d1 = DateTime(now.year, now.month, now.day - 10);
    final d2 = DateTime(now.year, now.month, now.day - 5);

    return [
      RequestModel(
        id: 1,
        requesterId: 2,
        requester: 'Ana Ribeiro',
        reason: 'Visita técnica a cliente',
        destination: 'Rio das Ostras',
        passengers: 2,
        departure: DateTime(d1.year, d1.month, d1.day, 8),
        returnDate: d1,
        returnPeriod: ReturnPeriod.manha,
        status: RequestStatus.finalizada,
        vehicleId: 1,
        departureMileage: 42100,
        returnMileage: 42260,
        checkOutAt: DateTime(d1.year, d1.month, d1.day, 8, 5),
        checkInAt: DateTime(d1.year, d1.month, d1.day, 11, 40),
        checkOutNotes: 'Tanque com 3/4.',
      ),
      RequestModel(
        id: 2,
        requesterId: 3,
        requester: 'Carlos Mendes',
        reason: 'Entrega de equipamentos',
        destination: 'Campos dos Goytacazes',
        passengers: 3,
        departure: DateTime(d2.year, d2.month, d2.day, 13),
        returnDate: d2,
        returnPeriod: ReturnPeriod.tarde,
        status: RequestStatus.finalizada,
        vehicleId: 1,
        departureMileage: 42260,
        returnMileage: 42500,
        checkOutAt: DateTime(d2.year, d2.month, d2.day, 13, 10),
        checkInAt: DateTime(d2.year, d2.month, d2.day, 19, 25),
        checkInNotes: 'Risco leve na porta traseira direita.',
      ),
    ];
  }

  /// Envia uma notificação ao solicitante.
  void _notify(RequestModel r, NotificationType type, String message) {
    NotificationController.instance.notify(
      userId: r.requesterId,
      requestId: r.id,
      type: type,
      destination: r.destination,
      message: message,
    );
  }

  /// Todas as solicitações, da mais recente para a mais antiga.
  List<RequestModel> get requests => List.unmodifiable(_requests.reversed);

  /// Apenas as solicitações aguardando decisão do aprovador.
  List<RequestModel> get pendingRequests => List.unmodifiable(
    _requests.reversed.where((r) => r.status == RequestStatus.pendente),
  );

  /// Solicitações de um usuário específico (mais recentes primeiro).
  List<RequestModel> requestsOf(int userId) => List.unmodifiable(
    _requests.reversed.where((r) => r.requesterId == userId),
  );

  /// Cria uma nova solicitação em nome do usuário logado.
  void addRequest({
    required String reason,
    required String destination,
    required int passengers,
    DateTime? departure,
    DateTime? returnDate,
    ReturnPeriod? returnPeriod,
  }) {
    final user = UserController.instance.currentUser;

    final request = RequestModel(
      id: _nextId++,
      requesterId: user.id,
      requester: user.name,
      reason: reason,
      destination: destination,
      passengers: passengers,
      departure: departure,
      returnDate: returnDate,
      returnPeriod: returnPeriod,
    );
    _requests.add(request);

    _notify(
      request,
      NotificationType.sent,
      'Sua solicitação foi enviada e aguarda aprovação.',
    );
    notifyListeners();
  }

  /// Edita uma solicitação (somente antes do check-out).
  ///
  /// - Motivo e destino: a aprovação continua valendo.
  /// - Datas, período ou passageiros em solicitação já aprovada:
  ///   volta para Pendente e o veículo é liberado para nova decisão.
  ///
  /// Retorna `true` se a solicitação voltou para aprovação.
  bool updateRequest(
    int id, {
    required String reason,
    required String destination,
    required int passengers,
    required DateTime departure,
    required DateTime returnDate,
    required ReturnPeriod returnPeriod,
  }) {
    final r = _requests.firstWhere((e) => e.id == id);
    if (!r.canEdit) return false;

    final needsReapproval =
        r.status == RequestStatus.aprovada &&
        (passengers != r.passengers ||
            departure != r.departure ||
            returnDate != r.returnDate ||
            returnPeriod != r.returnPeriod);

    r
      ..reason = reason
      ..destination = destination
      ..passengers = passengers
      ..departure = departure
      ..returnDate = returnDate
      ..returnPeriod = returnPeriod;

    if (needsReapproval) {
      r
        ..status = RequestStatus.pendente
        ..vehicleId = null;
      _notify(
        r,
        NotificationType.reverted,
        'Você alterou datas, período ou passageiros. A solicitação '
        'aguarda nova aprovação.',
      );
    }

    notifyListeners();
    return needsReapproval;
  }

  /// Cancela uma solicitação (somente enquanto estiver Pendente).
  void cancelRequest(int id) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status == RequestStatus.pendente) {
      request.status = RequestStatus.cancelada;
      _notify(
        request,
        NotificationType.canceled,
        'Você cancelou esta solicitação.',
      );
      notifyListeners();
    }
  }

  /// Aprova a solicitação e aloca o veículo escolhido pelo aprovador.
  /// Não altera o status do veículo: a reserva existe só na agenda.
  void approveRequest(int id, int vehicleId) {
    final request = _requests.firstWhere((e) => e.id == id);
    request
      ..status = RequestStatus.aprovada
      ..vehicleId = vehicleId
      ..rejectionReason = null;

    final v = vehicleOf(request);
    _notify(
      request,
      NotificationType.approved,
      v == null
          ? 'Sua solicitação foi aprovada.'
          : 'Veículo alocado: ${v.model} · ${v.plate}. '
                'Registre o check-out na retirada.',
    );

    notifyListeners();
  }

  /// Recusa a solicitação. A justificativa é obrigatória (regra 4.7).
  void rejectRequest(int id, String justification) {
    final request = _requests.firstWhere((e) => e.id == id);
    request
      ..status = RequestStatus.recusada
      ..rejectionReason = justification
      ..vehicleId = null;

    _notify(request, NotificationType.rejected, 'Motivo: $justification');
    notifyListeners();
  }

  /// Reservas ativas de um veículo: aprovadas (futuras) ou em uso.
  List<RequestModel> activeBookingsOf(int vehicleId) => _requests
      .where((r) => r.vehicleId == vehicleId && r.status.holdsVehicle)
      .toList();

  /// Devolve reservas aprovadas para Pendente, liberando o veículo.
  /// Usado quando o veículo fica indisponível ou perde lugares.
  void releaseBookings(Iterable<int> requestIds) {
    var changed = false;
    for (final r in _requests) {
      if (requestIds.contains(r.id) && r.status == RequestStatus.aprovada) {
        r
          ..status = RequestStatus.pendente
          ..vehicleId = null;
        _notify(
          r,
          NotificationType.reverted,
          'O veículo alocado ficou indisponível. Sua solicitação '
          'aguarda nova alocação.',
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Menor quilometragem aceita no check-out: o odômetro atual do veículo.
  int? minimumCheckOutMileage(RequestModel request) =>
      vehicleOf(request)?.mileage;

  String? _cleanNotes(String? notes) {
    final text = notes?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// CHECK-OUT — retirada do veículo, com observação opcional.
  /// Retorna `false` se a km for menor que a atual do veículo.
  bool checkOut(int id, int departureMileage, {String? notes}) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.aprovada) return false;

    final minimum = minimumCheckOutMileage(request);
    if (minimum != null && departureMileage < minimum) return false;

    request
      ..status = RequestStatus.emUso
      ..departureMileage = departureMileage
      ..checkOutAt = DateTime.now()
      ..checkOutNotes = _cleanNotes(notes);

    if (request.vehicleId != null) {
      VehicleController.instance.updateStatus(
        request.vehicleId!,
        VehicleStatus.emUso,
      );
    }

    notifyListeners();
    return true;
  }

  /// CHECK-IN — devolução do veículo, com observação opcional.
  /// Retorna `false` se a km de retorno for menor que a de saída.
  bool checkIn(int id, int returnMileage, {String? notes}) {
    final request = _requests.firstWhere((e) => e.id == id);
    if (request.status != RequestStatus.emUso) return false;

    final minimum = request.departureMileage;
    if (minimum != null && returnMileage < minimum) return false;

    request
      ..status = RequestStatus.finalizada
      ..returnMileage = returnMileage
      ..checkInAt = DateTime.now()
      ..checkInNotes = _cleanNotes(notes);

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

  /// Intervalo de tempo que uma solicitação ocupa na agenda.
  /// Em uso e com devolução atrasada: continua ocupando até o check-in.
  ({DateTime start, DateTime end})? _occupiedRange(RequestModel r) {
    final start = r.status == RequestStatus.emUso
        ? (r.checkOutAt ?? r.departure)
        : r.departure;
    var end = r.returnDeadline;
    if (start == null || end == null) return null;

    if (r.status == RequestStatus.emUso && end.isBefore(DateTime.now())) {
      end = DateTime(9999);
    }
    return (start: start, end: end);
  }

  /// Regra 4.4: o usuário não pode ter duas solicitações ativas
  /// (pendente, aprovada ou em uso) com períodos sobrepostos.
  bool userHasConflict({
    required int userId,
    required DateTime start,
    required DateTime end,
    int? ignoreRequestId,
  }) {
    for (final other in _requests) {
      if (other.requesterId != userId || other.id == ignoreRequestId) {
        continue;
      }
      if (!other.status.isActive) continue;

      final range = _occupiedRange(other);
      if (range == null) continue;

      if (periodsOverlap(start, end, range.start, range.end)) return true;
    }
    return false;
  }

  /// Regra RN 4.1: veículos elegíveis, ordenados por menor km.
  List<VehicleModel> eligibleVehicles(RequestModel request) {
    final eligible = VehicleController.instance.vehicles
        .where((v) => v.status.canBeScheduled)
        .where((v) => v.seats >= request.passengers)
        .where((v) => _isVehicleFree(v.id, request))
        .toList();

    eligible.sort((a, b) => a.mileage.compareTo(b.mileage));
    return eligible;
  }

  /// Regra 4.3: o veículo está livre durante todo o período pedido?
  bool _isVehicleFree(int vehicleId, RequestModel request) {
    final start = request.departure;
    final end = request.returnDeadline;
    if (start == null || end == null) return false;

    for (final other in _requests) {
      if (other.id == request.id || other.vehicleId != vehicleId) continue;
      if (!other.status.holdsVehicle) continue;

      final range = _occupiedRange(other);
      if (range == null) return false;

      if (periodsOverlap(start, end, range.start, range.end)) return false;
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
