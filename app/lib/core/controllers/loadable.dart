import 'package:flutter/material.dart';
import 'package:project/core/services/api_client.dart';

/// Estado de carregamento de uma lista vinda da API.
/// As telas mostram o indicador enquanto [loading] e a lista ainda está
/// vazia, e [error] (com "Tentar de novo") se a primeira carga falhar.
mixin Loadable on ChangeNotifier {
  bool loading = false;
  String? error;

  /// Executa [fetch] controlando [loading] e [error]. Nunca lança.
  Future<void> guardLoad(Future<void> Function() fetch) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await fetch();
    } on ApiError catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
