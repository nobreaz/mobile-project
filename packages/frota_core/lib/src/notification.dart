/// Tipos de notificação enviados ao solicitante.
enum NotificationType { sent, approved, rejected, canceled, reverted }

extension NotificationTypeX on NotificationType {
  String get title {
    switch (this) {
      case NotificationType.sent:
        return 'Solicitação enviada';
      case NotificationType.approved:
        return 'Solicitação aprovada';
      case NotificationType.rejected:
        return 'Solicitação recusada';
      case NotificationType.canceled:
        return 'Solicitação cancelada';
      case NotificationType.reverted:
        return 'Voltou para aprovação';
    }
  }
}

/// Notificação exibida dentro do app.
class AppNotification {
  final int id;
  final int userId; // destinatário
  final int requestId;
  final NotificationType type;
  final String destination;
  final String message;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.requestId,
    required this.type,
    required this.destination,
    required this.message,
    required this.createdAt,
    this.read = false,
  });
}
