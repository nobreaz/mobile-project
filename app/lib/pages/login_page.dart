import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/services/api_client.dart';

import '../../../core/components/app_logo.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/components/auth_background.dart';
import '../../../core/components/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String email = '';
  String senha = '';
  bool _loading = false;

  Future<void> _login() async {
    if (_loading) return;
    if (email.trim().isEmpty || senha.isEmpty) {
      _show('Informe e-mail e senha.');
      return;
    }

    setState(() => _loading = true);
    try {
      await UserController.instance.signIn(email, senha);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiError catch (e) {
      _show(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

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
                    variant: AppButtonVariant.login,
                    label: _loading ? 'Entrando...' : 'Entrar',
                    onPressed: _login,
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
