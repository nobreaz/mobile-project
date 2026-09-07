import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/components/notification_widget.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String reasonTravel = '';
  String destination = '';
  int numberPassengers = 0;
  DateTime? departureDateTime;
  DateTime? returnDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notificações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      NotificationWidget(
                        id: '1',
                        type: NotificationType.sent,
                        destination: 'Destino 1',
                        date: '01/01/2026 - 10:55',
                        message: 'Esta é uma notificação de exemplo.',
                      ),
                      SizedBox(height: 20),
                      NotificationWidget(
                        id: '1',
                        type: NotificationType.approved,
                        destination: 'Destino 2',
                        date: '01/01/2026 - 10:55',
                        message: 'Esta é uma notificação de exemplo.',
                      ),
                      SizedBox(height: 20),
                      NotificationWidget(
                        id: '1',
                        type: NotificationType.rejected,
                        destination: 'Destino 3',
                        date: '01/01/2026 - 10:55',
                        message: 'Esta é uma notificação de exemplo.',
                      ),
                      SizedBox(height: 20),
                      NotificationWidget(
                        id: '1',
                        type: NotificationType.canceled,
                        destination: 'Destino 4',
                        date: '01/01/2026 - 10:55',
                        message: 'Esta é uma notificação de exemplo.',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
