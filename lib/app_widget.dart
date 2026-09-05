import 'package:flutter/material.dart';
import 'package:project/app_controller.dart';
import 'package:project/pages/home_page.dart';
import 'package:project/pages/login_page.dart';
import 'package:project/pages/new_request_page.dart';
import 'package:project/pages/reset_password_page.dart';
import 'package:project/pages/settings_page.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: AppController.instance.isDarkTheme
                ? Brightness.dark
                : Brightness.light,
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => LoginPage(),
            '/reset-password': (context) => ResetPasswordPage(),
            '/home': (context) => HomePage(),
            '/new-request': (context) => const NewRequestPage(),
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}
