import 'package:flutter/material.dart';
import 'package:project/core/models/request_model.dart';

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

  /// Lista das solicitações, da mais recente para a mais antiga.
  List<RequestModel> get requests => List.unmodifiable(_requests.reversed);

  /// Cria uma nova solicitação (status inicial: Pendente) e avisa as telas.
  void addRequest({
    required String reason,
    required String destination,
    required int passengers,
    DateTime? departure,
    DateTime? returnDate,
  }) {
    _requests.add(
      RequestModel(
        id: _nextId++,
        reason: reason,
        destination: destination,
        passengers: passengers,
        departure: departure,
        returnDate: returnDate,
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
}
