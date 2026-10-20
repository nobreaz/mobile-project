import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart' show formatDate;
import 'package:project/core/controllers/loadable.dart';
import 'package:project/core/controllers/notification_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/services/api_client.dart';

/// Solicitações, vindas da API (`/solicitacoes`).
///
/// O servidor decide o que cada perfil vê (o Padrão recebe só as próprias)
/// e confere todas as regras: transições de status, conflitos de agenda
/// (4.3/4.4), km mínima, CNH. Ele também gera as notificações.
/// As ações lançam [ApiError] com a mensagem do servidor quando recusadas.
class RequestController extends ChangeNotifier with Loadable {
  RequestController._();
  static final RequestController instance = RequestController._();

  ApiClient get _api => ApiClient.instance;

  List<RequestModel> _requests = [];

  /// Todas as solicitações visíveis, da mais recente para a mais antiga.
  List<RequestModel> get requests => List.unmodifiable(_requests);

  Future<void> load() => guardLoad(() async {
    final list = await _api.get('/solicitacoes') as List;
    _requests = [
      for (final json in list)
        RequestModel.fromJson(json as Map<String, dynamic>),
    ]..sort((a, b) => b.id.compareTo(a.id));
  });

  /// Apaga os dados ao sair da conta.
  void clear() {
    _requests = [];
    error = null;
    notifyListeners();
  }

  /// Apenas as solicitações aguardando decisão do aprovador.
  List<RequestModel> get pendingRequests => List.unmodifiable(
    _requests.where((r) => r.status == RequestStatus.pendente),
  );

  /// Já aprovadas (aprovada, em uso ou finalizada) ou recusadas, por
  /// qualquer aprovador; mais recentes decisões primeiro.
  /// [approverId] limita às decididas por um aprovador ("só as minhas").
  List<RequestModel> decidedRequests({
    required bool approved,
    int? approverId,
  }) {
    final list =
        _requests
            .where(
              (r) =>
                  (approved
                      ? r.wasApproved
                      : r.status == RequestStatus.recusada) &&
                  (approverId == null || r.approverId == approverId),
            )
            .toList()
          ..sort((a, b) {
            final da = a.decidedAt, db = b.decidedAt;
            if (da == null || db == null) return b.id.compareTo(a.id);
            return db.compareTo(da);
          });
    return List.unmodifiable(list);
  }

  /// Solicitações de um usuário específico (mais recentes primeiro).
  List<RequestModel> requestsOf(int userId) =>
      List.unmodifiable(_requests.where((r) => r.requesterId == userId));

  /// Corpo de criação/edição no formato da API.
  Map<String, dynamic> _body({
    required String reason,
    required String destination,
    required int passengers,
    required DateTime departure,
    required DateTime returnDate,
    required ReturnPeriod returnPeriod,
  }) => {
    'reason': reason,
    'destination': destination,
    'passengers': passengers,
    'departure': departure.toUtc().toIso8601String(),
    'returnDate': formatDate(returnDate),
    'returnPeriod': returnPeriod.name,
  };

  /// Troca (ou acrescenta) a solicitação devolvida pela API e atualiza as
  /// notificações, que o servidor pode ter criado.
  RequestModel _store(Object? json) {
    final updated = RequestModel.fromJson(json! as Map<String, dynamic>);
    final exists = _requests.any((r) => r.id == updated.id);
    _requests = exists
        ? [for (final r in _requests) r.id == updated.id ? updated : r]
        : [updated, ..._requests];
    notifyListeners();
    NotificationController.instance.load();
    return updated;
  }

  /// Cria uma nova solicitação em nome do usuário logado.
  Future<RequestModel> addRequest({
    required String reason,
    required String destination,
    required int passengers,
    required DateTime departure,
    required DateTime returnDate,
    required ReturnPeriod returnPeriod,
  }) async => _store(
    await _api.post(
      '/solicitacoes',
      _body(
        reason: reason,
        destination: destination,
        passengers: passengers,
        departure: departure,
        returnDate: returnDate,
        returnPeriod: returnPeriod,
      ),
    ),
  );

  /// Edita uma solicitação (somente antes do check-out).
  ///
  /// - Motivo e destino: a aprovação continua valendo.
  /// - Datas, período ou passageiros em solicitação já aprovada:
  ///   volta para Pendente e o veículo é liberado para nova decisão.
  ///
  /// Retorna `true` se a solicitação voltou para aprovação.
  Future<bool> updateRequest(
    int id, {
    required String reason,
    required String destination,
    required int passengers,
    required DateTime departure,
    required DateTime returnDate,
    required ReturnPeriod returnPeriod,
  }) async {
    final wasApproved = _requests.any(
      (r) => r.id == id && r.status == RequestStatus.aprovada,
    );
    final updated = _store(
      await _api.patch(
        '/solicitacoes/$id',
        _body(
          reason: reason,
          destination: destination,
          passengers: passengers,
          departure: departure,
          returnDate: returnDate,
          returnPeriod: returnPeriod,
        ),
      ),
    );
    return wasApproved && updated.status == RequestStatus.pendente;
  }

  /// Cancela uma solicitação (somente enquanto estiver Pendente).
  Future<void> cancelRequest(int id) async =>
      _store(await _api.post('/solicitacoes/$id/cancelar', const {}));

  /// Aprova a solicitação e aloca o veículo escolhido pelo aprovador.
  /// Não altera o status do veículo: a reserva existe só na agenda.
  Future<void> approveRequest(int id, int vehicleId) async => _store(
    await _api.post('/solicitacoes/$id/aprovar', {'vehicleId': vehicleId}),
  );

  /// Recusa a solicitação. A justificativa é obrigatória (regra 4.7).
  Future<void> rejectRequest(int id, String justification) async => _store(
    await _api.post('/solicitacoes/$id/recusar', {
      'justification': justification,
    }),
  );

  /// Reservas ativas de um veículo: aprovadas (futuras) ou em uso.
  /// Só para avisar antes de alterar o veículo; quem libera é o servidor.
  List<RequestModel> activeBookingsOf(int vehicleId) => _requests
      .where((r) => r.vehicleId == vehicleId && r.status.holdsVehicle)
      .toList();

  /// Menor quilometragem aceita no check-out: o odômetro atual do veículo.
  int? minimumCheckOutMileage(RequestModel request) =>
      vehicleOf(request)?.mileage;

  /// CHECK-OUT — retirada do veículo, com observação opcional.
  /// O servidor recusa km menor que a atual do veículo.
  Future<void> checkOut(int id, int departureMileage, {String? notes}) async {
    _store(
      await _api.post('/solicitacoes/$id/retirada', {
        'mileage': departureMileage,
        'notes': notes,
      }),
    );
    await VehicleController.instance.load(); // status e km do veículo
  }

  /// CHECK-IN — devolução do veículo, com observação opcional.
  /// O servidor recusa km de retorno menor que a de saída (4.8).
  Future<void> checkIn(int id, int returnMileage, {String? notes}) async {
    _store(
      await _api.post('/solicitacoes/$id/devolucao', {
        'mileage': returnMileage,
        'notes': notes,
      }),
    );
    await VehicleController.instance.load();
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
  /// Conferência rápida na tela; o servidor confere de novo.
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

  /// Regra RN 4.1: veículos elegíveis, ordenados por menor km
  /// (calculado pelo servidor, que enxerga a agenda de toda a frota).
  Future<List<VehicleModel>> eligibleVehicles(RequestModel request) async {
    final list = await _api.get('/solicitacoes/${request.id}/veiculos') as List;
    return [
      for (final json in list)
        VehicleModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  /// Busca o veículo alocado a uma solicitação (ou nulo).
  VehicleModel? vehicleOf(RequestModel request) {
    final id = request.vehicleId;
    return id == null ? null : VehicleController.instance.byId(id);
  }
}
