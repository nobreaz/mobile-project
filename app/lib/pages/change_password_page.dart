import 'package:flutter/material.dart';
import 'package:frota_core/frota_core.dart' show PasswordRules;
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/input_text_field.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/services/api_client.dart';
import 'package:project/core/theme/app_colors.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  String currentPassword = '';
  String newPassword = '';
  String confirmPassword = '';

  // Trocar a "versão" recria os campos vazios (botão Limpar).
  int _formVersion = 0;

  // Regra 6.2, compartilhada com a API (frota_core).
  PasswordRules get _rules => PasswordRules(newPassword);
  bool get _hasMinLength => _rules.hasMinLength;
  bool get _hasNumber => _rules.hasNumber;
  bool get _hasSpecial => _rules.hasSpecial;
  bool get _matches => newPassword.isNotEmpty && newPassword == confirmPassword;

  void _clear() => setState(() {
    currentPassword = '';
    newPassword = '';
    confirmPassword = '';
    _formVersion++;
  });

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    if (currentPassword.isEmpty) {
      _show('Informe a senha atual.');
      return;
    }
    if (!_hasMinLength || !_hasNumber || !_hasSpecial) {
      _show('A nova senha não atende aos requisitos.');
      return;
    }
    if (!_matches) {
      _show('A confirmação não confere com a nova senha.');
      return;
    }
    if (newPassword == currentPassword) {
      _show('A nova senha precisa ser diferente da atual.');
      return;
    }

    setState(() => _saving = true);
    try {
      await UserController.instance.changePassword(
        currentPassword,
        newPassword,
      );
      if (!mounted) return;
      _show('Senha alterada com sucesso!');
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      _show(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                  child: KeyedSubtree(
                    key: ValueKey(_formVersion),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Senha atual',
                          type: InputFieldType.password,
                          inputText: '',
                          hint: '********',
                          onChanged: (text) =>
                              setState(() => currentPassword = text),
                        ),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Nova senha',
                          type: InputFieldType.password,
                          inputText: '',
                          hint: '********',
                          onChanged: (text) =>
                              setState(() => newPassword = text),
                        ),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Confirmar nova senha',
                          type: InputFieldType.password,
                          inputText: '',
                          hint: '********',
                          onChanged: (text) =>
                              setState(() => confirmPassword = text),
                        ),
                        const SizedBox(height: 20),
                        _requirements(),
                        const Spacer(),
                        const SizedBox(height: 40),
                        AppButton(
                          label: _saving ? 'Salvando...' : 'Confirmar',
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          variant: AppButtonVariant.cancel,
                          label: 'Limpar',
                          onPressed: _clear,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Lista de requisitos que marca ✓ conforme o usuário digita.
  Widget _requirements() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A nova senha precisa ter:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          _rule(_hasMinLength, 'No mínimo 6 caracteres'),
          _rule(_hasNumber, 'Pelo menos 1 número'),
          _rule(_hasSpecial, 'Pelo menos 1 caractere especial (ex.: @ # !)'),
          _rule(_matches, 'Confirmação igual à nova senha'),
        ],
      ),
    );
  }

  Widget _rule(bool ok, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? AppColors.approved : AppColors.iconMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ok ? Colors.black87 : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
