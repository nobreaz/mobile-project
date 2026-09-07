import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/input_text_field.dart';
import 'package:project/core/theme/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  String password = '';
  String confirmPassword = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Alterar Senha',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      InputTextField(
                        label: 'Senha atual',
                        type: InputFieldType.password,
                        inputText: '',
                        hint: '********',
                        onChanged: (text) => password = text,
                      ),
                      const SizedBox(height: 20),
                      InputTextField(
                        label: 'Nova senha',
                        type: InputFieldType.password,
                        inputText: '',
                        hint: '********',
                        onChanged: (text) => confirmPassword = text,
                      ),
                      const SizedBox(height: 20),
                      InputTextField(
                        label: 'Confirmar nova senha',               
                        type: InputFieldType.password,
                        inputText: '',
                        hint: '********',
                        onChanged: (text) => confirmPassword = text,
                      ),
                      const Spacer(),
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            AppButton(label: 'Confirmar', onPressed: () {}),
                            const SizedBox(height: 10),
                            AppButton(
                              variant: AppButtonVariant.cancel,
                              label: 'Limpar',
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
