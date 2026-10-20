import 'package:flutter/material.dart';
import 'package:project/core/controllers/loadable.dart';
import 'package:project/core/models/report_model.dart';
import 'package:project/core/services/api_client.dart';

/// Relatórios da frota (`GET /relatorios`), só Aprovador e Administrador.
/// Carregado ao abrir a tela e ao trocar o período (não no login).
class ReportController extends ChangeNotifier with Loadable {
  ReportController._();
  static final ReportController instance = ReportController._();

  ApiClient get _api => ApiClient.instance;

  /// Períodos oferecidos na tela (dias → rótulo). Os mesmos do servidor.
  static const periods = {
    7: '7 dias',
    30: '30 dias',
    90: '90 dias',
    365: '12 meses',
  };

  /// Período escolhido na tela. Pode estar à frente de [report] enquanto
  /// a troca carrega; quem diz o período dos dados é `report.days`.
  int days = 30;
  FleetReport? report;

  /// Conta as cargas: só a mais recente pode gravar o resultado.
  int _lastLoad = 0;

  Future<void> load() async {
    final requested = days;
    final ticket = ++_lastLoad;
    await guardLoad(() async {
      final json = await _api.get('/relatorios?dias=$requested');
      // Trocou de período de novo antes desta resposta chegar: descarta,
      // senão o relatório antigo sobrescreveria o novo.
      if (ticket != _lastLoad) return;
      report = FleetReport.fromJson(json as Map<String, dynamic>);
    });
    // Falhou: o seletor volta para o período que está sendo mostrado.
    final shown = report;
    if (ticket == _lastLoad && error != null && shown != null) {
      days = shown.days;
      notifyListeners();
    }
  }

  /// Troca o período e recarrega (a tela mostra o anterior enquanto isso).
  Future<void> setDays(int value) {
    days = value;
    return load();
  }

  /// Apaga os dados ao sair da conta.
  void clear() {
    report = null;
    days = 30;
    error = null;
    notifyListeners();
  }
}
