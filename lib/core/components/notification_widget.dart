import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

enum NotificationType { sent, approved, rejected, canceled }

class NotificationWidget extends StatelessWidget {
  final String message;
  final String id;
  final String destination;
  final String? date;
  final NotificationType type;

  const NotificationWidget({
    super.key,
    required this.destination,
    required this.message,
    required this.id,
    required this.type,
    this.date,
  });

  TextStyle _getTextStyle() {
    switch (type) {
      case NotificationType.sent:
        return const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      case NotificationType.approved:
        return const TextStyle(
          color: AppColors.approved,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      case NotificationType.rejected:
        return const TextStyle(
          color: AppColors.rejected,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
      case NotificationType.canceled:
        return const TextStyle(
          color: AppColors.canceled,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        );
    }
  }

  String getTitle() {
    switch (type) {
      case NotificationType.sent:
        return 'Solicitação Enviada';
      case NotificationType.approved:
        return 'Solicitação Aprovada';
      case NotificationType.rejected:
        return 'Solicitação Rejeitada';
      case NotificationType.canceled:
        return 'Solicitação Cancelada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        shadows: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(getTitle(), style: _getTextStyle()),
              Text(
                date ?? '',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Viagem a $destination',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Column(
                children: [
                  SizedBox(height: 4),
                  Text(
                    'Solicitação',
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '#$id',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
