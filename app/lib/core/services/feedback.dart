import 'package:flutter/material.dart';
import 'package:project/core/services/api_client.dart';

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Executa uma ação que chama a API e avisa o resultado num SnackBar:
/// [success] se der certo, a mensagem do servidor se der errado.
/// Devolve `true` se deu certo.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } on ApiError catch (e) {
    if (context.mounted) showSnack(context, e.details);
    return false;
  }
}
