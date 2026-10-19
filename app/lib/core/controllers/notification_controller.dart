import 'package:flutter/material.dart';
import 'package:project/core/models/notification_model.dart';

/// Guarda as notificações em memória.
///
/// Quando o backend entrar, as notificações passam a vir do servidor
/// (e podem virar push no celular) — as telas não mudam.
class NotificationController extends ChangeNotifier {
  NotificationController._();
  static final NotificationController instance = NotificationController._();

  final List<AppNotification> _items = [];
  int _nextId = 1;

  /// Notificações de um usuário, mais recentes primeiro.
  List<AppNotification> notificationsOf(int userId) =>
      List.unmodifiable(_items.reversed.where((n) => n.userId == userId));

  int unreadCountOf(int userId) =>
      _items.where((n) => n.userId == userId && !n.read).length;

  void notify({
    required int userId,
    required int requestId,
    required NotificationType type,
    required String destination,
    required String message,
  }) {
    _items.add(
      AppNotification(
        id: _nextId++,
        userId: userId,
        requestId: requestId,
        type: type,
        destination: destination,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void markAllRead(int userId) {
    var changed = false;
    for (final n in _items) {
      if (n.userId == userId && !n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}
