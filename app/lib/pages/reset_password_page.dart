import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart' show isValidEmail;
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/auth_background.dart';
import 'package:project/core/components/auth_text_field.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/services/api_client.dart';
import 'package:project/core/theme/app_text_styles.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  String email = '';
  bool _loading = false;

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    if (_loading) return;
    if (!isValidEmail(email)) {
      _show('Informe um e-mail válido.');
      return;
    }

    setState(() => _loading = true);
    try {
      await UserController.instance.sendPasswordReset(email);
      // Mesma mensagem exista ou não o e-mail: não revela quem tem cadastro.
      _show(
        'Se o e-mail estiver cadastrado, você receberá um link para '
        'redefinir a senha.',
      );
    } on ApiError catch (e) {
      _show(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        children: (context, dividerY) => [
          Positioned(
            top: dividerY + (119.10 / 2) - 20,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Text(
                    'Recuperar senha',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading,
                  ),
                  const Text(
                    'Digite seu e-mail para redefinir sua senha',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    label: 'E-mail',
                    icon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (text) => email = text,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: _loading ? 'Enviando...' : 'Recuperar senha',
                    onPressed: _send,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    variant: AppButtonVariant.cancel,
                    label: 'Voltar',
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/');
                    },
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
