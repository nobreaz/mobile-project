import 'package:flutter/material.dart';
import 'package:project/core/models/notification_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Card de uma notificação.
class NotificationWidget extends StatelessWidget {
  final String id;
  final NotificationType type;
  final String destination;
  final String? date;
  final String message;
  final bool isNew;

  const NotificationWidget({
    super.key,
    required this.id,
    required this.type,
    required this.destination,
    required this.message,
    this.date,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isNew
              ? BorderSide(color: type.color, width: 1.5)
              : BorderSide.none,
        ),
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(type.icon, size: 20, color: type.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.title,
                        style: TextStyle(
                          color: type.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: type.color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'NOVA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Viagem a $destination',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  'Solicitação #$id${date != null ? ' · $date' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
