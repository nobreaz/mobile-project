import 'package:flutter/material.dart';
import 'package:project/core/components/notification_widget.dart';
import 'package:project/core/controllers/notification_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  /// Não lidas no momento em que a tela abriu (ficam destacadas).
  final Set<int> _unreadAtOpen = {};

  void _collectUnread(int userId) {
    _unreadAtOpen.addAll(
      NotificationController.instance
          .notificationsOf(userId)
          .where((n) => !n.read)
          .map((n) => n.id),
    );
  }

  @override
  void initState() {
    super.initState();
    final userId = UserController.instance.currentUser.id;
    _collectUnread(userId);

    // Busca as novas no servidor e só então marca todas como lidas.
    NotificationController.instance.load().then((_) {
      if (!mounted) return;
      setState(() => _collectUnread(userId));
      NotificationController.instance.markAllRead(userId);
    });
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmt(DateTime d) =>
      '${_pad(d.day)}/${_pad(d.month)}/${d.year} - ${_pad(d.hour)}:${_pad(d.minute)}';

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
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: NotificationController.instance,
        builder: (context, _) {
          final userId = UserController.instance.currentUser.id;
          final items = NotificationController.instance.notificationsOf(userId);

          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 72,
                    color: AppColors.iconMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma notificação',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Atualizações das suas solicitações aparecerão aqui.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final n = items[index];
              return NotificationWidget(
                id: '${n.requestId}',
                type: n.type,
                destination: n.destination,
                date: _fmt(n.createdAt),
                message: n.message,
                isNew: _unreadAtOpen.contains(n.id),
              );
            },
          );
        },
      ),
    );
  }
}
