import 'package:flutter/material.dart';
import 'package:project/core/components/home_page_action_button.dart';
import 'package:project/core/components/home_page_header.dart';
import 'package:project/core/components/home_page_wide_action_button.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/theme/app_text_styles.dart';

enum TipoUsuario { user, approver }

class HomePageAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const HomePageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class HomePage extends StatelessWidget {
  final TipoUsuario tipoUsuario;

  // const HomePage({super.key, required this.tipoUsuario}); - Mudar quando for implementar autenticação
  const HomePage({
    super.key,
    this.tipoUsuario = TipoUsuario.approver,
  }); // Mudar quando for implementar autenticação

  List<HomePageAction> _gridActions(BuildContext context) {
    final actions = <HomePageAction>[
      HomePageAction(
        label: 'Nova Solicitação',
        icon: Icons.add_circle_outline,
        onPressed: () => Navigator.of(context).pushNamed('/new-request'),
      ),
      HomePageAction(
        label: 'Minhas Solicitações',
        icon: Icons.list_alt,
        onPressed: () {},
      ),
      HomePageAction(
        label: 'Agenda',
        icon: Icons.calendar_month,
        onPressed: () {},
      ),
    ];

    if (tipoUsuario == TipoUsuario.approver) {
      actions.addAll([
        HomePageAction(
          label: 'Ver Relatórios',
          icon: Icons.bar_chart,
          onPressed: () {},
        ),
        HomePageAction(
          label: 'Gestão de Veículos',
          icon: Icons.directions_car,
          onPressed: () {},
        ),
        HomePageAction(
          label: 'Solicitações Pendentes',
          icon: Icons.pending_actions,
          onPressed: () {},
        ),
      ]);
    } else {
      // usuário padrão: Configurações continua dentro do grid
      actions.add(
        HomePageAction(
          label: 'Configurações',
          icon: Icons.settings,
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _gridActions(context);
    final isApprover = tipoUsuario == TipoUsuario.approver;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: HomePageHeader(
                name: 'Nome Sobrenome',
                role: 'Cargo',
                onLogout: () => Navigator.of(context).pushReplacementNamed('/'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Olá, Nome!', style: AppTextStyles.welcomeMessage),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
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
                          );
                        },
                      ),
                    ),
                    if (isApprover) ...[
                      const SizedBox(height: 16),
                      HomePageWideActionButton(
                        label: 'Configurações',
                        icon: Icons.settings,
                        onPressed: () => {
                          Navigator.of(context).pushNamed('/settings'),
                        },
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
  }
}
