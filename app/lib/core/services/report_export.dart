import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frota_core/frota_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Exportação da tela "Ver Relatórios" em PDF.
///
/// O PDF é mais completo que a tela: além das mesmas seções, traz a
/// situação atual de cada veículo, o histórico das viagens do período e as
/// solicitações recusadas com a justificativa. É montado no próprio app,
/// com o relatório e as listas de veículos e solicitações já carregadas.

/// Uma tabela do PDF.
class ExportTable {
  const ExportTable(
    this.title,
    this.headers,
    this.rows, {
    this.note,
    this.widths,
    this.newPage = false,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;

  /// Explicação curta abaixo do título (ex.: o que conta como atraso).
  final String? note;

  /// Largura relativa de cada coluna (tabelas com muitas colunas).
  final List<double>? widths;

  /// Começa numa página nova (tabelas longas, como o histórico).
  final bool newPage;
}

String _pad(int v) => v.toString().padLeft(2, '0');
String _date(DateTime d) => '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
String _dateTime(DateTime d) => '${_date(d)} ${_pad(d.hour)}:${_pad(d.minute)}';
String _shortDateTime(DateTime d) =>
    '${_pad(d.day)}/${_pad(d.month)} ${_pad(d.hour)}:${_pad(d.minute)}';
String _percent(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

/// 1234 → "1.234".
String _int(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

const _months = [
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

/// Nome do arquivo: `relatorio-frota-30-dias-2026-10-20.pdf`.
String exportFileName(FleetReport r, DateTime now) =>
    'relatorio-frota-${r.days}-dias-'
    '${now.year}-${_pad(now.month)}-${_pad(now.day)}.pdf';

/// Vencimento com a situação: "10/10/2026 (vencido)".
String _expiry(DateTime? date) {
  if (date == null) return '—';
  return switch (expiryStatusOf(date)) {
    ExpiryStatus.vencido => '${_date(date)} (vencido)',
    ExpiryStatus.vencendo => '${_date(date)} (vence logo)',
    _ => _date(date),
  };
}

/// Revisão: "aos 50.000 km (faltam 420)".
String _service(VehicleModel v) {
  final next = v.nextServiceMileage;
  if (next == null) return '—';
  return switch (v.serviceStatus) {
    ExpiryStatus.vencido => 'aos ${_int(next)} km (atrasada)',
    ExpiryStatus.vencendo =>
      'aos ${_int(next)} km (faltam ${_int(next - v.mileage)})',
    _ => 'aos ${_int(next)} km',
  };
}

/// Todas as seções do PDF, como tabelas de texto.
///
/// [vehicles] e [requests]: as listas completas (Aprovador e Administrador
/// recebem todas). O histórico e as recusadas usam o mesmo período do
/// relatório: os últimos `r.days` dias até [now].
List<ExportTable> reportTables(
  FleetReport r, {
  required List<VehicleModel> vehicles,
  required List<RequestModel> requests,
  required DateTime now,
}) {
  final from = now.subtract(Duration(days: r.days));
  bool inPeriod(DateTime? d) =>
      d != null && !d.isBefore(from) && !d.isAfter(now);
  final vehicleById = {for (final v in vehicles) v.id: v};
  String vehicleName(int? id) {
    final v = vehicleById[id];
    return v == null ? '—' : '${v.model} ${v.plate}';
  }

  // Viagens = retiradas no período (mesma regra do servidor), recentes primeiro.
  final trips =
      requests
          .where(
            (q) =>
                (q.status == RequestStatus.emUso ||
                    q.status == RequestStatus.finalizada) &&
                inPeriod(q.checkOutAt),
          )
          .toList()
        ..sort((a, b) => b.checkOutAt!.compareTo(a.checkOutAt!));

  final refused =
      requests
          .where(
            (q) => q.status == RequestStatus.recusada && inPeriod(q.decidedAt),
          )
          .toList()
        ..sort((a, b) => b.decidedAt!.compareTo(a.decidedAt!));

  return [
    ExportTable(
      'Resumo',
      const ['Indicador', 'Valor'],
      [
        ['Viagens no período', '${r.trips}'],
        ['Viagens devolvidas', '${r.finishedTrips}'],
        ['Devolvidas no prazo', _percent(r.onTimeRate)],
        ['Devolvidas com atraso', '${r.lateReturns}'],
        ['Solicitações criadas', '${r.requests}'],
        ['Taxa de aprovação', _percent(r.approvalRate)],
      ],
    ),
    ExportTable(
      'Precisa de atenção',
      const ['Situação', 'Item', 'Detalhe'],
      [
        for (final a in r.alerts)
          [a.critical ? 'Urgente' : 'Atenção', a.title, a.message],
      ],
      widths: const [1.2, 2.5, 5],
    ),
    ExportTable(
      'Situação atual da frota',
      const [
        'Veículo',
        'Placa',
        'Status',
        'Km atual',
        'Licenciamento',
        'Seguro',
        'Revisão',
      ],
      [
        for (final v in vehicles)
          [
            v.model,
            v.plate,
            v.status.label,
            _int(v.mileage),
            _expiry(v.licensingExpiry),
            _expiry(v.insuranceExpiry),
            _service(v),
          ],
      ],
      note: 'Na data de geração do relatório.',
      widths: const [2.1, 1.5, 2, 1.3, 2.1, 2.1, 2.6],
    ),
    ExportTable(
      r.granularity == TrendGranularity.week
          ? 'Viagens por semana'
          : 'Viagens por mês',
      const ['Período', 'Viagens'],
      [
        for (final t in r.trend)
          [
            r.granularity == TrendGranularity.week
                ? 'Semana de ${_date(t.start)}'
                : '${_months[t.start.month - 1]}/${t.start.year}',
            '${t.trips}',
          ],
      ],
    ),
    ExportTable(
      'Quem mais viajou',
      const ['Nome', 'Setor', 'Viagens', 'Atrasos'],
      [
        for (final u in r.users)
          [u.label, u.detail ?? '', '${u.trips}', '${u.lateReturns}'],
      ],
      note: 'Atrasos = devoluções depois do prazo.',
    ),
    ExportTable(
      'Veículos mais utilizados',
      const ['Veículo', 'Placa', 'Viagens', 'Km rodados'],
      [
        for (final v in r.vehicles)
          [v.label, v.detail ?? '', '${v.trips}', _int(v.km)],
      ],
      note:
          'Km das viagens já devolvidas. Parados no período aparecem com zero.',
    ),
    ExportTable(
      'Viagens por setor',
      const ['Setor', 'Viagens', '% do total'],
      [
        for (final d in r.departments)
          [
            d.label,
            '${d.trips}',
            _percent(r.trips == 0 ? null : d.trips / r.trips),
          ],
      ],
    ),
    ExportTable(
      'Solicitações por status',
      const ['Status', 'Quantidade'],
      [
        for (final s in RequestStatus.values)
          if ((r.statuses[s] ?? 0) > 0) [s.label, '${r.statuses[s]}'],
      ],
      note: 'Solicitações criadas no período, pelo status atual.',
    ),
    ExportTable(
      'Aprovadores',
      const ['Aprovador', 'Aprovadas', 'Recusadas'],
      [
        for (final a in r.approvers) [a.name, '${a.approved}', '${a.rejected}'],
      ],
      note: 'Decisões tomadas no período.',
    ),
    ExportTable(
      'Histórico de viagens',
      const [
        'Retirada',
        'Devolução',
        'Solicitante',
        'Veículo',
        'Destino',
        'Km',
        'Situação',
      ],
      [
        for (final q in trips)
          [
            _shortDateTime(q.checkOutAt!),
            q.checkInAt == null ? '—' : _shortDateTime(q.checkInAt!),
            q.requester,
            vehicleName(q.vehicleId),
            q.destination,
            q.distanceTravelled == null ? '—' : _int(q.distanceTravelled!),
            q.status == RequestStatus.emUso
                ? (q.isReturnLate ? 'Em uso, atrasada' : 'Em uso')
                : (q.wasReturnedLate ? 'Com atraso' : 'No prazo'),
          ],
      ],
      note: 'Veículos retirados no período, do mais recente ao mais antigo.',
      newPage: true,
      widths: const [1.5, 1.5, 2.2, 2.4, 2.2, 1, 1.7],
    ),
    ExportTable(
      'Solicitações recusadas',
      const ['Recusada em', 'Solicitante', 'Destino', 'Por', 'Justificativa'],
      [
        for (final q in refused)
          [
            _shortDateTime(q.decidedAt!),
            q.requester,
            q.destination,
            q.approverName ?? '—',
            q.rejectionReason ?? '—',
          ],
      ],
      note: 'Recusadas no período.',
      widths: const [1.5, 2, 2, 1.8, 4],
    ),
  ];
}

const _primary = PdfColor.fromInt(0xFF173A6F);
const _muted = PdfColor.fromInt(0xFF7A7C7E);
const _line = PdfColor.fromInt(0xFFDDDDDD);

/// PDF A4 com cabeçalho, as tabelas de [reportTables] e numeração de
/// páginas. Usa a fonte do app (Instrument Sans), que tem os acentos.
Future<Uint8List> buildReportPdf(
  FleetReport r, {
  required List<VehicleModel> vehicles,
  required List<RequestModel> requests,
  required DateTime now,
}) async {
  Future<pw.Font> font(String weight) async => pw.Font.ttf(
    await rootBundle.load('assets/fonts/InstrumentSans-$weight.ttf'),
  );
  final theme = pw.ThemeData.withFont(
    base: await font('Regular'),
    bold: await font('Bold'),
  );

  final doc = pw.Document(
    title: 'Relatório da frota',
    author: 'Gestor de Frotas',
    theme: theme,
  );

  final tables = reportTables(
    r,
    vehicles: vehicles,
    requests: requests,
    now: now,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => context.pageNumber == 1
          ? pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _primary, width: 2),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Relatório da frota',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Últimos ${r.periodLabel}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${_date(now.subtract(Duration(days: r.days)))} a '
                        '${_date(now)} · gerado às '
                        '${_pad(now.hour)}:${_pad(now.minute)}',
                        style: const pw.TextStyle(fontSize: 9, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : pw.SizedBox(),
      footer: (context) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Relatório da frota · gerado em ${_dateTime(now)}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
      build: (context) => [for (final t in tables) ..._pdfTable(t)],
    ),
  );
  return doc.save();
}

List<pw.Widget> _pdfTable(ExportTable t) {
  // Tabelas largas (muitas colunas) usam letra um pouco menor.
  final fontSize = t.headers.length > 5 ? 8.0 : 9.0;
  pw.Alignment align(int i) => i > 0 && _isNumeric(t, i)
      ? pw.Alignment.centerRight
      : pw.Alignment.centerLeft;

  return [
    if (t.newPage) pw.NewPage() else pw.SizedBox(height: 14),
    pw.Text(
      t.title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: _primary,
      ),
    ),
    if (t.note != null)
      pw.Text(t.note!, style: const pw.TextStyle(fontSize: 8, color: _muted)),
    pw.SizedBox(height: 6),
    if (t.rows.isEmpty)
      pw.Text(
        'Nada no período.',
        style: const pw.TextStyle(fontSize: 9, color: _muted),
      )
    else
      pw.TableHelper.fromTextArray(
        headers: t.headers,
        data: t.rows,
        border: null,
        columnWidths: t.widths == null
            ? null
            : {
                for (final (i, w) in t.widths!.indexed)
                  i: pw.FlexColumnWidth(w),
              },
        headerStyle: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: _muted,
        ),
        headerDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _muted)),
        ),
        cellStyle: pw.TextStyle(fontSize: fontSize),
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
        ),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        // 1ª coluna (nome) à esquerda; números à direita.
        cellAlignments: {
          for (var i = 0; i < t.headers.length; i++) i: align(i),
        },
        headerAlignments: {
          for (var i = 0; i < t.headers.length; i++) i: align(i),
        },
      ),
  ];
}

/// Coluna em que todas as células são número ou porcentagem.
bool _isNumeric(ExportTable t, int column) =>
    t.rows.every((row) => RegExp(r'^([\d.]+%?|—)$').hasMatch(row[column]));

/// Gera o PDF e abre o menu de compartilhar do sistema (WhatsApp, e-mail,
/// Drive, salvar em arquivos...). No navegador, baixa o arquivo.
/// [origin]: widget que abriu o menu (o iPad precisa da posição).
Future<void> shareReportPdf(
  FleetReport r, {
  required List<VehicleModel> vehicles,
  required List<RequestModel> requests,
  BuildContext? origin,
}) async {
  final now = DateTime.now();
  final bytes = await buildReportPdf(
    r,
    vehicles: vehicles,
    requests: requests,
    now: now,
  );
  final name = exportFileName(r, now);
  final box = origin?.findRenderObject() as RenderBox?;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
      fileNameOverrides: [name],
      subject: 'Relatório da frota: últimos ${r.periodLabel}',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
