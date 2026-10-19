import 'package:flutter/material.dart';
import 'package:project/app_controller.dart';
import 'package:project/core/theme/app_text_styles.dart';
import 'package:project/pages/agenda_page.dart';
import 'package:project/pages/change_password_page.dart';
import 'package:project/pages/home_page.dart';
import 'package:project/pages/login_page.dart';
import 'package:project/pages/my_data_page.dart';
import 'package:project/pages/my_requests_page.dart';
import 'package:project/pages/new_request_page.dart';
import 'package:project/pages/notifications_page.dart';
import 'package:project/pages/pending_requests_page.dart';
import 'package:project/pages/reset_password_page.dart';
import 'package:project/pages/settings_page.dart';
import 'package:project/pages/users_page.dart';
import 'package:project/pages/vehicles_page.dart';

class AppWidget extends StatelessWidget {
  /// '/' (login) ou '/home' quando já existe uma sessão salva.
  final String initialRoute;

  const AppWidget({super.key, this.initialRoute = '/'});

  /// Permite navegar de fora das telas (ex.: sessão expirou → login).
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: AppTextStyles.fontFamily, // Instrument Sans no app todo
            brightness: AppController.instance.isDarkTheme
                ? Brightness.dark
                : Brightness.light,
          ),
          initialRoute: initialRoute,
          // Abre SÓ a rota inicial (sem empilhar o login embaixo da home).
          onGenerateInitialRoutes: (name) => [
            MaterialPageRoute(
              settings: RouteSettings(name: name),
              builder: _routes[name] ?? _routes['/']!,
            ),
          ],
          routes: _routes,
        );
      },
    );
  }

  static final Map<String, WidgetBuilder> _routes = {
    '/': (context) => const LoginPage(),
    '/reset-password': (context) => const ResetPasswordPage(),
    '/home': (context) => const HomePage(),
    '/new-request': (context) => const NewRequestPage(),
    '/my-requests': (context) => const MyRequestsPage(),
    '/agenda': (context) => const AgendaPage(),
    '/vehicles': (context) => const VehiclesPage(),
    '/pending-requests': (context) => const PendingRequestsPage(),
    '/users': (context) => const UsersPage(),
    '/settings': (context) => const SettingsPage(),
    '/change-password': (context) => const ChangePasswordPage(),
    '/notifications': (context) => const NotificationsPage(),
    '/my-data': (context) => const MyDataPage(),
  };
}
