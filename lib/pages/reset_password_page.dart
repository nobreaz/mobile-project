import 'package:flutter/material.dart';
import 'package:project/core/components/app_button.dart';
import 'package:project/core/components/auth_background.dart';
import 'package:project/core/components/auth_text_field.dart';
import 'package:project/core/theme/app_text_styles.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
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
                  SizedBox(height: 20),
                  AuthTextField(
                    label: 'E-mail',
                    icon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (text) {},
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Recuperar senha',
                    onPressed: () {
                      // Lógica para redefinir a senha
                    },
                  ),
                  SizedBox(height: 10),
                  AppButton(
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
