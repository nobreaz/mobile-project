import 'package:flutter/material.dart';

import '../../../core/components/app_logo.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/components/auth_background.dart';
import '../../../core/components/auth_text_field.dart';
import '../../../core/components/app_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = '';
  String senha = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        children: (context, dividerY) => [
          AppLogo(dividerY: dividerY),
          Positioned(
            top: dividerY + (119.10 / 2) + 20,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Bem-vindo!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),
                  const Text(
                    'Aplicativo de Solicitação de Frotas',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  AuthTextField(
                    label: 'E-mail',
                    icon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (text) => email = text,
                  ),
                  AuthTextField(
                    label: 'Senha',
                    icon: Icons.lock,
                    obscureable: true,
                    onChanged: (text) => senha = text,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Entrar',
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/home'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushReplacementNamed('/reset-password'),
                    child: const Text(
                      'Esqueci minha senha',
                      style: AppTextStyles.link,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
