import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

/// Pede confirmação e encerra a sessão, voltando para o login.
///
/// O histórico de navegação é limpo para que o botão "voltar"
/// não retorne às telas internas depois de sair.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sair da conta'),
      content: const Text('Deseja realmente sair do aplicativo?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Sair',
            style: TextStyle(color: AppColors.rejected),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Quando houver Firebase: await FirebaseAuth.instance.signOut();
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
