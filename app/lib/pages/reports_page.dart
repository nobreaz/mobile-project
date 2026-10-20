import 'package:flutter/material.dart';
import 'package:project/core/components/load_state.dart';
import 'package:project/core/components/report_widgets.dart';
import 'package:project/core/controllers/report_controller.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/report_model.dart';
import 'package:project/core/services/report_export.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/theme/app_text_styles.dart';

/// Tela "Ver Relatórios" (Aprovador e Administrador).
///
/// De cima para baixo: o que precisa de atenção agora, os números do
/// período, a evolução das viagens, os rankings (pessoas, veículos,
/// setores), o fluxo de solicitações e os aprovadores. O botão da barra
/// exporta tudo em PDF, com mais detalhes (frota e histórico).
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.loadOnOpen = true});

  /// `false` nos testes: mostra o relatório já carregado no controller.
  final bool loadOnOpen;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  /// A lista de alertas começa recolhida para não empurrar o resto.
  static const _alertsPreview = 4;
  bool _showAllAlerts = false;
  bool _exporting = false;

  /// Gera o PDF do período na tela e abre o menu de compartilhar.
  /// Antes, atualiza veículos e solicitações (situação da frota e
  /// histórico do PDF), para não sair com dados velhos.
  Future<void> _exportPdf(BuildContext buttonContext) async {
    final report = _controller.report;
    if (report == null) return;

    void show(String text) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));

    setState(() => _exporting = true);
    try {
      final vehicles = VehicleController.instance;
      final requests = RequestController.instance;
      await Future.wait([vehicles.load(), requests.load()]);
      final error = vehicles.error ?? requests.error;
      if (error != null) {
        if (mounted) show('Não foi possível gerar o PDF: $error');
        return;
      }

      await shareReportPdf(
        report,
        vehicles: vehicles.vehicles,
        requests: requests.requests,
        origin: buttonContext.mounted ? buttonContext : null,
      );
    } on Object catch (e) {
      if (mounted) show('Não foi possível gerar o PDF: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  ReportController get _controller => ReportController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relatórios',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Só exporta com um relatório carregado e fora de recarga.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Exportar PDF',
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed:
                  _controller.report == null ||
                      _controller.loading ||
                      _exporting
                  ? null
                  : () => _exportPdf(context),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: RefreshOnOpen(
        loaders: [if (widget.loadOnOpen) _controller.load],
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final report = _controller.report;
            return Column(
              children: [
                _periodSelector(),
                // Trocando o período: mostra o relatório anterior + barra.
                SizedBox(
                  height: 3,
                  child: _controller.loading && report != null
                      ? const LinearProgressIndicator()
                      : null,
                ),
                // A troca falhou: avisa que os dados são do período anterior.
                if (_controller.error != null && report != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Não foi possível atualizar (${_controller.error}). '
                      'Mostrando os últimos '
                      '${report.periodLabel}.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.rejected,
                      ),
                    ),
                  ),
                Expanded(
                  child: report == null
                      ? LoadState(
                          loading: _controller.loading,
                          error: _controller.error,
                          onRetry: _controller.load,
                          empty: const SizedBox.shrink(),
                        )
                      : RefreshIndicator(
                          onRefresh: _controller.load,
                          child: _content(report),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            selectedBackgroundColor: AppColors.primary,
            selectedForegroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            visualDensity: VisualDensity.compact,
          ),
          segments: [
            for (final e in ReportController.periods.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {_controller.days},
          onSelectionChanged: (s) => _controller.setDays(s.single),
        ),
      ),
    );
  }

  Widget _content(FleetReport r) {
    const gap = SizedBox(height: 16);
    final weekly = r.granularity == TrendGranularity.week;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _alerts(r.alerts),
        gap,
        _stats(r),
        gap,
        ReportSection(
          title: weekly ? 'Viagens por semana' : 'Viagens por mês',
          icon: Icons.show_chart,
          child: TrendBars(points: r.trend, granularity: r.granularity),
        ),
        gap,
        ReportSection(
          title: 'Quem mais viajou',
          icon: Icons.emoji_events_outlined,
          child: r.users.isEmpty
              ? const ReportEmpty('Nenhuma viagem no período.')
              : ReportTable(
                  headers: const ['Nome', 'Viagens', 'Atrasos'],
                  rows: [
                    for (final u in r.users)
                      [
                        ReportCell(u.label, detail: u.detail),
                        ReportCell(formatInt(u.trips)),
                        ReportCell(
                          formatInt(u.lateReturns),
                          warning: u.lateReturns > 0,
                          muted: u.lateReturns == 0,
                        ),
                      ],
                  ],
                ),
        ),
        gap,
        ReportSection(
          title: 'Veículos mais utilizados',
          subtitle: 'Km das viagens já devolvidas.',
          icon: Icons.directions_car,
          child: r.vehicles.isEmpty
              ? const ReportEmpty('Nenhum veículo cadastrado.')
              : ReportTable(
                  headers: const ['Veículo', 'Viagens', 'Km rodados'],
                  rows: [
                    for (final v in r.vehicles)
                      [
                        ReportCell(
                          v.label,
                          detail: v.detail,
                          muted: v.trips == 0,
                        ),
                        ReportCell(formatInt(v.trips), muted: v.trips == 0),
                        ReportCell(formatInt(v.km), muted: v.trips == 0),
                      ],
                  ],
                ),
        ),
        gap,
        ReportSection(
          title: 'Viagens por setor',
          icon: Icons.apartment,
          child: r.departments.isEmpty
              ? const ReportEmpty('Nenhuma viagem no período.')
              : ReportTable(
                  headers: const ['Setor', 'Viagens', '% do total'],
                  rows: [
                    for (final d in r.departments)
                      [
                        ReportCell(d.label),
                        ReportCell(formatInt(d.trips)),
                        ReportCell(formatPercent(d.trips / r.trips)),
                      ],
                  ],
                ),
        ),
        gap,
        ReportSection(
          title: 'Solicitações por status',
          subtitle:
              '${plural(r.requests, 'solicitação criada', 'solicitações criadas')} '
              'no período',
          icon: Icons.donut_large,
          child: r.requests == 0
              ? const ReportEmpty('Nenhuma solicitação no período.')
              : StatusBreakdown(statuses: r.statuses),
        ),
        gap,
        ReportSection(
          title: 'Aprovadores',
          subtitle: 'Decisões tomadas no período',
          icon: Icons.how_to_reg_outlined,
          child: r.approvers.isEmpty
              ? const ReportEmpty('Nenhuma decisão no período.')
              : ReportTable(
                  headers: const ['Aprovador', 'Aprovadas', 'Recusadas'],
                  rows: [
                    for (final a in r.approvers)
                      [
                        ReportCell(a.name),
                        ReportCell(formatInt(a.approved)),
                        ReportCell(formatInt(a.rejected)),
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _alerts(List<ReportAlert> alerts) {
    final visible = _showAllAlerts
        ? alerts
        : alerts.take(_alertsPreview).toList();
    final critical = alerts.where((a) => a.critical).length;

    return ReportSection(
      title: 'Precisa de atenção',
      subtitle: alerts.isEmpty
          ? null
          : '${plural(alerts.length, 'item', 'itens')}'
                '${critical == 0 ? '' : ', $critical urgente(s)'}',
      icon: Icons.warning_amber_rounded,
      child: alerts.isEmpty
          ? const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.approved, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tudo em dia: documentos, revisões, CNHs e devoluções.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (final (i, a) in visible.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  AlertTile(alert: a),
                ],
                if (alerts.length > _alertsPreview)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllAlerts = !_showAllAlerts),
                    child: Text(
                      _showAllAlerts
                          ? 'Mostrar menos'
                          : 'Ver todos (${alerts.length})',
                    ),
                  ),
              ],
            ),
    );
  }

  /// Três números do período, lado a lado.
  Widget _stats(FleetReport r) {
    final tiles = [
      StatTile(
        label: 'Viagens',
        value: formatInt(r.trips),
        caption: plural(r.finishedTrips, 'devolvida', 'devolvidas'),
      ),
      StatTile(
        label: 'No prazo',
        value: formatPercent(r.onTimeRate),
        caption: '${r.lateReturns} com atraso',
      ),
      StatTile(
        label: 'Aprovação',
        value: formatPercent(r.approvalRate),
        caption: 'de ${r.approved + r.rejected} pedidos',
      ),
    ];

    // Cada cartão com a altura do maior (sem proporção fixa: não corta
    // com tela estreita ou fonte grande).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tile),
          ],
        ],
      ),
    );
  }
}
