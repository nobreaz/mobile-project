import 'package:flutter/material.dart';
import 'package:project/core/controllers/loadable.dart';
import 'package:project/core/models/notification_model.dart';
import 'package:project/core/services/api_client.dart';

/// Notificações do usuário logado, vindas da API (`/notificacoes`).
///
/// Quem cria é o servidor, junto com cada mudança de solicitação.
/// Recarregadas ao entrar no app, depois de cada ação e ao abrir a tela.
class NotificationController extends ChangeNotifier with Loadable {
  NotificationController._();
  static final NotificationController instance = NotificationController._();

  ApiClient get _api => ApiClient.instance;

  List<AppNotification> _items = [];

  Future<void> load() => guardLoad(() async {
    final list = await _api.get('/notificacoes') as List;
    _items = [
      for (final json in list)
        AppNotification.fromJson(json as Map<String, dynamic>),
    ];
  });

  /// Apaga os dados ao sair da conta.
  void clear() {
    _items = [];
    error = null;
    notifyListeners();
  }

  /// Notificações de um usuário, mais recentes primeiro.
  List<AppNotification> notificationsOf(int userId) =>
      List.unmodifiable(_items.where((n) => n.userId == userId));

  int unreadCountOf(int userId) =>
      _items.where((n) => n.userId == userId && !n.read).length;

  /// Marca todas como lidas (na tela já; no servidor em seguida).
  Future<void> markAllRead(int userId) async {
    if (unreadCountOf(userId) == 0) return;
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
    try {
      await _api.post('/notificacoes/lidas', const {});
    } on ApiError {
      // Sem rede: continuam lidas na tela; o servidor marca na próxima vez.
    }
  }
}
