import 'package:flutter/material.dart';
import 'package:project/app_widget.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/services/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isComplete) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  // Sessão expirada ou revogada (ex.: usuário desativado): volta ao login.
  ApiClient.instance.onUnauthorized = () async {
    if (!UserController.instance.isLoggedIn) return;
    await UserController.instance.signOut();
    AppWidget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/',
      (_) => false,
    );
  };

  final loggedIn = await UserController.instance.restoreSession();
  runApp(AppWidget(initialRoute: loggedIn ? '/home' : '/'));
}

/// Aparece quando o app foi aberto sem o arquivo de configuração.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Configuração ausente.\n\n'
              'Rode com: flutter run --dart-define-from-file=env/dev.json\n'
              '(copie env/example.json para env/dev.json e preencha).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
