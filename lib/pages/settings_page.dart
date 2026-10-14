import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/logout_dialog.dart';
import 'package:project/core/controllers/notification_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        UserController.instance,
        NotificationController.instance,
      ]),
      builder: (context, _) {
        final user = UserController.instance.currentUser;
        final unread = NotificationController.instance.unreadCountOf(user.id);
        final width = MediaQuery.of(context).size.width;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Configurações',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Center(
              child: Column(
                children: [
                  // Card do usuário
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    width: width * 0.9,
                    decoration: ShapeDecoration(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadows: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 4,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 34,
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          user.role,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Opções
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Alterar Senha',
                    variant: AppButtonVariant.settings,
                    onPressed: () =>
                        Navigator.pushNamed(context, '/change-password'),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: unread > 0
                        ? 'Notificações ($unread)'
                        : 'Notificações',
                    variant: AppButtonVariant.settings,
                    onPressed: () =>
                        Navigator.pushNamed(context, '/notifications'),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Meus dados',
                    variant: AppButtonVariant.settings,
                    onPressed: () => Navigator.pushNamed(context, '/my-data'),
                  ),

                  const Spacer(),
                  AppButton(
                    label: 'Sair',
                    variant: AppButtonVariant.logout,
                    onPressed: () => confirmLogout(context),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
