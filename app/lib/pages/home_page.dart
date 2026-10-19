import 'package:flutter/material.dart';
import 'package:project/core/components/home_page_action_button.dart';
import 'package:project/core/components/home_page_header.dart';
import 'package:project/core/components/home_page_wide_action_button.dart';
import 'package:project/core/components/logout_dialog.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/theme/app_text_styles.dart';

class HomePageAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool comingSoon;

  const HomePageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.comingSoon = false,
  });
}

/// Tela inicial. Os cards exibidos dependem do perfil do usuário logado.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Cards de cada perfil (segregação de funções, ver UserProfile):
  /// - Padrão: solicita e acompanha as próprias viagens.
  /// - Aprovador: decide solicitações e consulta a frota (sem editar).
  /// - Administrador: cadastra veículos e usuários.
  /// Configurações fica no grid do Padrão e num botão largo nos demais.
  List<HomePageAction> _gridActions(BuildContext context, UserProfile profile) {
    void go(String route) => Navigator.of(context).pushNamed(route);

    final agenda = HomePageAction(
      label: 'Agenda',
      icon: Icons.calendar_month,
      onPressed: () => go('/agenda'),
    );
    final reports = HomePageAction(
      label: 'Ver Relatórios',
      icon: Icons.bar_chart,
      onPressed: () {},
      comingSoon: true,
    );

    switch (profile) {
      case UserProfile.padrao:
        return [
          HomePageAction(
            label: 'Nova Solicitação',
            icon: Icons.add_circle_outline,
            onPressed: () => go('/new-request'),
          ),
          HomePageAction(
            label: 'Minhas Solicitações',
            icon: Icons.list_alt,
            onPressed: () => go('/my-requests'),
          ),
          agenda,
          HomePageAction(
            label: 'Configurações',
            icon: Icons.settings,
            onPressed: () => go('/settings'),
          ),
        ];
      case UserProfile.aprovador:
        return [
          HomePageAction(
            label: 'Solicitações',
            icon: Icons.pending_actions,
            onPressed: () => go('/pending-requests'),
          ),
          agenda,
          HomePageAction(
            label: 'Frota',
            icon: Icons.directions_car,
            onPressed: () => go('/vehicles'),
          ),
          reports,
        ];
      case UserProfile.administrador:
        return [
          HomePageAction(
            label: 'Gestão de Veículos',
            icon: Icons.directions_car,
            onPressed: () => go('/vehicles'),
          ),
          HomePageAction(
            label: 'Gestão de Usuários',
            icon: Icons.people_outline,
            onPressed: () => go('/users'),
          ),
          agenda,
          reports,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserController.instance,
      builder: (context, _) {
        final user = UserController.instance.currentUser;
        final wideSettings = user.profile != UserProfile.padrao;
        final actions = _gridActions(context, user.profile);
        final firstName = user.name.trim().split(RegExp(r'\s+')).first;

        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: HomePageHeader(
                    name: user.name,
                    role: user.role,
                    onLogout: () => confirmLogout(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Olá, $firstName!',
                    style: AppTextStyles.welcomeMessage,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GridView.builder(
                            itemCount: actions.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                            itemBuilder: (context, index) {
                              final action = actions[index];
                              return HomePageActionButton(
                                label: action.label,
                                icon: action.icon,
                                onPressed: action.onPressed,
                                comingSoon: action.comingSoon,
                              );
                            },
                          ),
                        ),
                        if (wideSettings) ...[
                          const SizedBox(height: 16),
                          HomePageWideActionButton(
                            label: 'Configurações',
                            icon: Icons.settings,
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/settings'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
