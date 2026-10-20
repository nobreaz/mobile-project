import 'package:flutter/material.dart';
import 'package:project/core/models/report_model.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/theme/app_colors.dart';

// Peças da tela de Relatórios, feitas com widgets simples (sem
// biblioteca de gráficos): cartões de número, tabelas, barras por período
// e uma barra empilhada de status. Valores sempre escritos em texto, para
// não depender só da cor nem do tamanho.

/// 1234 → "1.234".
String formatInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 0.756 → "76%". `null` → "—".
String formatPercent(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

String plural(int n, String one, String many) =>
    '${formatInt(n)} ${n == 1 ? one : many}';

/// Cartão branco com título, usado em cada bloco da tela.
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Número de destaque (KPI) com legenda.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Texto de "sem dados" dentro de uma seção.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
    );
  }
}

/// Uma célula das tabelas: texto, linha de detalhe opcional embaixo e
/// destaque (amarelo) ou apagado (cinza).
class ReportCell {
  const ReportCell(
    this.text, {
    this.detail,
    this.warning = false,
    this.muted = false,
  });

  final String text;
  final String? detail;
  final bool warning;
  final bool muted;
}

/// Tabela simples: a 1ª coluna (nome) ocupa o espaço que sobra e é cortada
/// com "…" se for longa; as demais são números alinhados à direita.
class ReportTable extends StatelessWidget {
  const ReportTable({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<List<ReportCell>> rows;

  static const _divider = BorderSide(color: Color(0xFFE6E6E6));

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(),
        for (var i = 1; i < headers.length; i++)
          i: const IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.iconMuted)),
          ),
          children: [
            for (final (i, h) in headers.indexed)
              _pad(
                i,
                Text(
                  h,
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        for (final (r, row) in rows.indexed)
          TableRow(
            decoration: r == rows.length - 1
                ? null
                : const BoxDecoration(border: Border(bottom: _divider)),
            children: [
              for (final (i, cell) in row.indexed) _pad(i, _cell(i, cell)),
            ],
          ),
      ],
    );
  }

  Widget _pad(int column, Widget child) => Padding(
    padding: EdgeInsets.fromLTRB(column == 0 ? 0 : 12, 8, 0, 8),
    child: child,
  );

  Widget _cell(int column, ReportCell cell) {
    final color = cell.warning
        ? const Color(0xFF8A6500)
        : cell.muted
        ? AppColors.textMuted
        : null;
    final main = Text(
      cell.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: column == 0 ? TextAlign.left : TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: column == 0 || cell.warning
            ? FontWeight.w700
            : FontWeight.w600,
        color: color,
      ),
    );
    if (cell.detail == null) return main;
    return Column(
      crossAxisAlignment: column == 0
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        main,
        Text(
          cell.detail!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Viagens por semana ou mês: barras verticais com o número em cima.
/// Tocar numa barra mostra o período completo (útil quando o rótulo de
/// baixo é pulado).
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.points, required this.granularity});

  final List<TrendPoint> points;
  final TrendGranularity granularity;

  static const _months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  String _label(DateTime d) => granularity == TrendGranularity.month
      ? _months[d.month - 1]
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _tooltip(TrendPoint p) {
    final when = granularity == TrendGranularity.month
        ? '${_months[p.start.month - 1]}/${p.start.year}'
        : 'Semana de ${_label(p.start)}';
    return '$when: ${plural(p.trips, 'viagem', 'viagens')}';
  }

  @override
  Widget build(BuildContext context) {
    const chartHeight = 120.0;
    final max = points.fold(0, (m, p) => p.trips > m ? p.trips : m);
    // Muitas barras (ex.: 13 semanas): rótulo só em uma sim, outra não.
    final labelEvery = points.length > 8 ? 2 : 1;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, p) in points.indexed)
            Expanded(
              child: Tooltip(
                message: _tooltip(p),
                triggerMode: TooltipTriggerMode.tap,
                child: Padding(
                  // 2px de folga entre barras vizinhas.
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (p.trips > 0)
                        Text(
                          '${p.trips}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: max == 0
                            ? 2
                            : (chartHeight * p.trips / max).clamp(
                                2,
                                chartHeight,
                              ),
                        constraints: const BoxConstraints(maxWidth: 28),
                        decoration: BoxDecoration(
                          color: p.trips == 0
                              ? AppColors.background
                              : AppColors.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: i % labelEvery == 0
                            ? FittedBox(
                                child: Text(
                                  _label(p.start),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Solicitações por status: uma barra empilhada (100%) + legenda com
/// número e porcentagem de cada status.
class StatusBreakdown extends StatelessWidget {
  const StatusBreakdown({super.key, required this.statuses});

  final Map<RequestStatus, int> statuses;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final s in RequestStatus.values)
        if ((statuses[s] ?? 0) > 0) (s, statuses[s]!),
    ];
    final total = entries.fold(0, (sum, e) => sum + e.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final (i, (status, count)) in entries.indexed)
                  Expanded(
                    flex: count,
                    child: Container(
                      // 2px de folga entre segmentos.
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      color: status.color,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (status, count) in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${status.label}: $count '
                    '(${formatPercent(count / total)})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Uma linha da seção "Precisa de atenção".
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert});

  final ReportAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.critical ? AppColors.rejected : AppColors.canceled;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(alert.kind.icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(alert.message, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (alert.critical)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text(
                'URGENTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.rejected,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
