import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Cores da pré-reserva (solicitação pendente, ainda sem veículo).
const Color _pendingGray = Color(0xFF8A8D91);
const Color _pendingFill = Color(0xFFF4F4F5);

/// Modo de visualização da agenda.
enum AgendaView { dia, semana }

/// Categorias usadas no filtro de status da agenda.
enum _AgendaCategory { preReserva, aprovada, emUso, finalizada, atrasada }

extension _AgendaCategoryX on _AgendaCategory {
  String get label {
    switch (this) {
      case _AgendaCategory.preReserva:
        return 'Pré-reserva';
      case _AgendaCategory.aprovada:
        return 'Aprovada';
      case _AgendaCategory.emUso:
        return 'Em uso';
      case _AgendaCategory.finalizada:
        return 'Finalizada';
      case _AgendaCategory.atrasada:
        return 'Atrasada';
    }
  }

  Color get color {
    switch (this) {
      case _AgendaCategory.preReserva:
        return _pendingGray;
      case _AgendaCategory.aprovada:
        return RequestStatus.aprovada.color;
      case _AgendaCategory.emUso:
        return RequestStatus.emUso.color;
      case _AgendaCategory.finalizada:
        return RequestStatus.finalizada.color;
      case _AgendaCategory.atrasada:
        return AppColors.rejected;
    }
  }
}

/// Tela "Agenda" — calendário de reservas no estilo Teams/Outlook.
/// Requisitos 3.3.2 (agendador) e 3.3.5 (agenda por veículo).
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  // Grade de 24h; ao abrir, a tela rola até perto do horário atual.
  static const int _startHour = 0;
  static const int _endHour = 24;
  static const double _hourHeight = 56;
  static const double _timeColumnWidth = 44;

  static const Color _gridLine = Color(0xFFE0E0E0);
  static const Color _gridLineLight = Color(0xFFF2F2F2);

  static const _weekdaysShort = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];
  static const _weekdaysFull = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];
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

  AgendaView _view = AgendaView.semana;
  late DateTime _anchor; // dia de referência da navegação
  Timer? _clock;
  final ScrollController _scroll = ScrollController();

  // Filtro de veículos (rodapé). Começa em "Nenhum".
  bool _showAll = false;
  final Set<int> _selectedVehicles = {};

  // Filtro de status (topo). Começa com todos ligados.
  final Set<_AgendaCategory> _categories = {..._AgendaCategory.values};

  bool get _showsNothing => !_showAll && _selectedVehicles.isEmpty;

  @override
  void initState() {
    super.initState();
    _anchor = _dateOnly(DateTime.now());
    RequestController.instance.load();
    VehicleController.instance.load();

    // Atualiza a linha do "agora" a cada minuto.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Datas e navegação
  // ---------------------------------------------------------------------

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtTime(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';

  String _fmtDateTime(DateTime? d) => d == null
      ? '—'
      : '${_pad(d.day)}/${_pad(d.month)}/${d.year} ${_fmtTime(d)}';

  /// Dias exibidos: 1 (visão Dia) ou segunda a domingo (Semana).
  List<DateTime> get _days {
    if (_view == AgendaView.dia) return [_anchor];
    final monday = DateTime(
      _anchor.year,
      _anchor.month,
      _anchor.day - (_anchor.weekday - 1),
    );
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  String get _rangeLabel {
    final days = _days;
    final first = days.first;
    final last = days.last;

    if (_view == AgendaView.dia) {
      return '${_weekdaysShort[first.weekday - 1]}, '
          '${first.day} ${_months[first.month - 1]} ${first.year}';
    }
    if (first.month == last.month) {
      return '${first.day}–${last.day} ${_months[first.month - 1]} ${first.year}';
    }
    return '${first.day} ${_months[first.month - 1]} – '
        '${last.day} ${_months[last.month - 1]}';
  }

  void _move(int direction) {
    final step = _view == AgendaView.dia ? 1 : 7;
    setState(() {
      _anchor = DateTime(
        _anchor.year,
        _anchor.month,
        _anchor.day + step * direction,
      );
    });
  }

  void _goToday() {
    setState(() => _anchor = _dateOnly(DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  void _scrollToNow() {
    if (!_scroll.hasClients) return;
    final now = DateTime.now();
    final target =
        ((now.hour - _startHour) + now.minute / 60) * _hourHeight - 80;
    _scroll.jumpTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent).toDouble(),
    );
  }

  // ---------------------------------------------------------------------
  // Filtros
  // ---------------------------------------------------------------------

  /// Categoria de uma solicitação no filtro de status.
  /// Reservas atrasadas entram apenas em "Atrasada".
  _AgendaCategory? _categoryOf(RequestModel r) {
    if (r.status == RequestStatus.pendente) return _AgendaCategory.preReserva;
    if (r.isCheckOutLate || r.isReturnLate) return _AgendaCategory.atrasada;
    switch (r.status) {
      case RequestStatus.aprovada:
        return _AgendaCategory.aprovada;
      case RequestStatus.emUso:
        return _AgendaCategory.emUso;
      case RequestStatus.finalizada:
        return _AgendaCategory.finalizada;
      default:
        return null; // recusada, cancelada
    }
  }

  bool _passesFilters(RequestModel r) {
    final category = _categoryOf(r);
    if (category == null || !_categories.contains(category)) return false;

    // Pré-reservas não têm veículo: aparecem só com "Todos".
    if (r.status == RequestStatus.pendente) return _showAll;

    if (_showAll) return true;
    return _selectedVehicles.contains(r.vehicleId);
  }

  void _selectNone() => setState(() {
    _showAll = false;
    _selectedVehicles.clear();
  });

  void _toggleCategory(_AgendaCategory c) => setState(() {
    if (!_categories.remove(c)) _categories.add(c);
  });

  // ---------------------------------------------------------------------
  // Eventos
  // ---------------------------------------------------------------------

  /// Intervalo ocupado por uma solicitação na agenda.
  DateTimeRange? _rangeOf(RequestModel r) {
    DateTime? start;
    DateTime? end;

    switch (r.status) {
      case RequestStatus.pendente: // pré-reserva (regra 4.5)
      case RequestStatus.aprovada:
        start = r.departure;
        end = r.returnDeadline;
      case RequestStatus.emUso:
        start = r.checkOutAt ?? r.departure;
        end = r.returnDeadline;
        final now = DateTime.now();
        // Devolução atrasada: o evento se estende até agora.
        if (end != null && end.isBefore(now)) end = now;
      case RequestStatus.finalizada:
        start = r.checkOutAt ?? r.departure;
        end = r.checkInAt ?? r.returnDeadline;
      default:
        return null; // recusada, cancelada
    }

    if (start == null || end == null || end.isBefore(start)) return null;
    return DateTimeRange(start: start, end: end);
  }

  /// Recorta as solicitações no dia informado (reservas de vários dias
  /// aparecem em cada dia que ocupam).
  List<_Segment> _segmentsFor(DateTime day, List<RequestModel> requests) {
    final dayStart = DateTime(day.year, day.month, day.day, _startHour);
    final dayEnd = DateTime(day.year, day.month, day.day, _endHour);
    final result = <_Segment>[];

    for (final r in requests) {
      final range = _rangeOf(r);
      if (range == null) continue;

      final start = range.start.isAfter(dayStart) ? range.start : dayStart;
      final end = range.end.isBefore(dayEnd) ? range.end : dayEnd;
      if (!end.isAfter(start)) continue;

      final top = start.difference(dayStart).inMinutes / 60 * _hourHeight;
      var height = end.difference(start).inMinutes / 60 * _hourHeight;
      if (height < 22) height = 22;

      result.add(_Segment(r, range, start, end, top, height));
    }

    _layoutLanes(result);
    return result;
  }

  /// Eventos simultâneos ficam lado a lado (colunas/"lanes").
  void _layoutLanes(List<_Segment> segments) {
    segments.sort((a, b) => a.start.compareTo(b.start));

    final cluster = <_Segment>[];
    final laneEnds = <DateTime>[];
    DateTime? clusterEnd;

    void flush() {
      for (final s in cluster) {
        s.lanes = laneEnds.length;
      }
      cluster.clear();
      laneEnds.clear();
    }

    for (final s in segments) {
      if (clusterEnd != null && !s.start.isBefore(clusterEnd)) {
        flush();
        clusterEnd = null;
      }

      var lane = laneEnds.indexWhere((e) => !s.start.isBefore(e));
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(s.end);
      } else {
        laneEnds[lane] = s.end;
      }
      s.lane = lane;
      cluster.add(s);

      if (clusterEnd == null || s.end.isAfter(clusterEnd)) {
        clusterEnd = s.end;
      }
    }
    flush();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        RequestController.instance,
        VehicleController.instance,
      ]),
      builder: (context, _) {
        final allVehicles = VehicleController.instance.vehicles;

        // Remove da seleção veículos que foram excluídos.
        _selectedVehicles.removeWhere(
          (id) => !allVehicles.any((v) => v.id == id),
        );

        // Seletor: apenas veículos ativos.
        final activeVehicles = allVehicles
            .where(
              (v) =>
                  v.status != VehicleStatus.emManutencao &&
                  v.status != VehicleStatus.inativo,
            )
            .toList();

        final requests = RequestController.instance.requests
            .where(_passesFilters)
            .toList();

        final days = _days;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Agenda',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          backgroundColor: Colors.white,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).pushNamed('/new-request'),
            icon: const Icon(Icons.add),
            label: const Text(
              'Nova',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          bottomNavigationBar: _vehicleFooter(activeVehicles),
          body: Column(
            children: [
              _toolbar(),
              _statusFilters(),
              _dayHeader(days),
              if (_showsNothing) _emptyHint(),
              Expanded(child: _grid(days, requests)),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _goToday,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Hoje',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => _move(-1),
            icon: const Icon(Icons.chevron_left),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Anterior',
          ),
          IconButton(
            onPressed: () => _move(1),
            icon: const Icon(Icons.chevron_right),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Próximo',
          ),
          Expanded(
            child: Text(
              _rangeLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          PopupMenuButton<AgendaView>(
            initialValue: _view,
            onSelected: (v) => setState(() => _view = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: AgendaView.dia, child: Text('Dia')),
              PopupMenuItem(value: AgendaView.semana, child: Text('Semana')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.view_week_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _view == AgendaView.dia ? 'Dia' : 'Semana',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtro de status no topo (também funciona como legenda de cores).
  Widget _statusFilters() {
    Widget marker(_AgendaCategory c) {
      if (c == _AgendaCategory.preReserva) {
        return CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            _pendingGray,
            radius: 3,
            dash: 2,
            gap: 1.5,
            strokeWidth: 1.2,
          ),
          child: const ColoredBox(color: _pendingFill),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    return Container(
      color: Colors.white,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final c in _AgendaCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: _categories.contains(c),
                onSelected: (_) => _toggleCategory(c),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selectedColor: AppColors.primary.withValues(alpha: 0.10),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _categories.contains(c)
                      ? AppColors.primary
                      : const Color(0xFFD0D0D0),
                ),
                label: Opacity(
                  opacity: _categories.contains(c) ? 1 : 0.45,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12, child: marker(c)),
                      const SizedBox(width: 6),
                      Text(
                        c.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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

  /// Rodapé compacto: resumo da seleção + botão para abrir o seletor.
  Widget _vehicleFooter(List<VehicleModel> vehicles) {
    final String summary;
    if (_showAll) {
      summary = 'Todos os veículos';
    } else if (_selectedVehicles.isEmpty) {
      summary = 'Nenhum selecionado';
    } else if (_selectedVehicles.length == 1) {
      final match = vehicles.where((v) => v.id == _selectedVehicles.first);
      summary = match.isEmpty
          ? '1 veículo selecionado'
          : '${match.first.model} · ${match.first.plate}';
    } else {
      summary = '${_selectedVehicles.length} veículos selecionados';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _gridLine)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.directions_car_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Veículos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      summary,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_showsNothing)
                IconButton(
                  onPressed: _selectNone,
                  icon: const Icon(Icons.close),
                  color: AppColors.iconMuted,
                  tooltip: 'Limpar seleção',
                ),
              ElevatedButton.icon(
                onPressed: () => _openVehiclePicker(vehicles),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text(
                  'Selecionar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Abre o painel de seleção de veículos e aplica o resultado.
  Future<void> _openVehiclePicker(List<VehicleModel> vehicles) async {
    final result = await showModalBottomSheet<_VehicleSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VehiclePickerSheet(
        vehicles: vehicles,
        showAll: _showAll,
        selected: _selectedVehicles,
      ),
    );

    if (result == null) return; // fechou sem aplicar

    setState(() {
      _showAll = result.showAll;
      _selectedVehicles
        ..clear()
        ..addAll(result.ids);
    });
  }

  Widget _emptyHint() {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nenhum veículo selecionado. Toque em "Selecionar" no rodapé.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(List<DateTime> days) {
    final today = DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _gridLine),
          bottom: BorderSide(color: _gridLine),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          for (final d in days)
            Expanded(child: _dayHeaderCell(d, _isSameDay(d, today))),
        ],
      ),
    );
  }

  Widget _dayHeaderCell(DateTime day, bool isToday) {
    final isDayView = _view == AgendaView.dia;
    final weekday = isDayView
        ? _weekdaysFull[day.weekday - 1]
        : _weekdaysShort[day.weekday - 1];
    final isWeekend = day.weekday >= 6;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 2, 6),
      decoration: BoxDecoration(
        color: isWeekend ? const Color(0xFFFAFAFA) : null,
        border: Border(
          left: const BorderSide(color: _gridLine),
          top: BorderSide(
            color: isToday ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: isDayView ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.primary : Colors.black87,
            ),
          ),
          Text(
            weekday,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isToday ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<DateTime> days, List<RequestModel> requests) {
    final totalHeight = (_endHour - _startHour) * _hourHeight;

    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _timeColumn(),
            for (final d in days) Expanded(child: _dayColumn(d, requests)),
          ],
        ),
      ),
    );
  }

  Widget _timeColumn() {
    return SizedBox(
      width: _timeColumnWidth,
      child: Column(
        children: [
          for (var h = _startHour; h < _endHour; h++)
            SizedBox(
              height: _hourHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Text(
                    h == _startHour ? '' : '${_pad(h)}:00',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayColumn(DateTime day, List<RequestModel> requests) {
    final segments = _segmentsFor(day, requests);
    final isToday = _isSameDay(day, DateTime.now());
    final isWeekend = day.weekday >= 6;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.04)
                : (isWeekend ? const Color(0xFFFAFAFA) : Colors.white),
            border: const Border(left: BorderSide(color: _gridLine)),
          ),
          child: Stack(
            children: [
              // Linhas das horas e meias horas
              for (var h = 0; h < _endHour - _startHour; h++) ...[
                Positioned(
                  top: h * _hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: _gridLine),
                ),
                Positioned(
                  top: h * _hourHeight + _hourHeight / 2,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: _gridLineLight),
                ),
              ],
              for (final s in segments) _eventTile(s, width),
              if (isToday) ..._nowLine(),
            ],
          ),
        );
      },
    );
  }

  Widget _eventTile(_Segment s, double columnWidth) {
    final r = s.request;
    final isPending = r.status == RequestStatus.pendente;
    final vehicle = RequestController.instance.vehicleOf(r);
    final color = r.status.color;
    final isLate = r.isCheckOutLate || r.isReturnLate;
    final laneWidth = columnWidth / s.lanes;
    final isDayView = _view == AgendaView.dia;

    final String title;
    if (isPending) {
      title = 'Pré-reserva';
    } else if (vehicle == null) {
      title = 'Veículo removido';
    } else {
      title = isDayView ? '${vehicle.model} · ${vehicle.plate}' : vehicle.plate;
    }

    final maxLines = ((s.height - 4) / 13).floor().clamp(1, 6);

    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          TextSpan(text: '\n${r.destination}'),
          TextSpan(
            text: '\n${_fmtTime(s.range.start)}–${_fmtTime(s.range.end)}',
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        height: 1.25,
        color: isPending ? _pendingGray : Colors.black87,
      ),
    );

    // Pré-reserva: fundo cinza claro + borda cinza tracejada.
    // Demais status: fundo colorido + faixa lateral sólida.
    final Widget tile = isPending
        ? CustomPaint(
            foregroundPainter: _DashedBorderPainter(_pendingGray),
            child: Container(
              color: _pendingFill,
              padding: const EdgeInsets.fromLTRB(5, 3, 3, 3),
              child: text,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              color: color.withValues(alpha: 0.18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    color: isLate ? AppColors.rejected : color,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                      child: text,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Positioned(
      top: s.top,
      height: s.height,
      left: s.lane * laneWidth + 1,
      width: laneWidth - 2,
      child: GestureDetector(onTap: () => _showDetails(r), child: tile),
    );
  }

  /// Linha do horário atual (como a do Teams).
  List<Widget> _nowLine() {
    final now = DateTime.now();
    final minutes = (now.hour - _startHour) * 60 + now.minute;
    if (minutes < 0 || minutes > (_endHour - _startHour) * 60) return [];

    final top = minutes / 60 * _hourHeight;
    return [
      Positioned(
        top: top - 1,
        left: 0,
        right: 0,
        child: Container(height: 2, color: AppColors.rejected),
      ),
      Positioned(
        top: top - 5,
        left: 0,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.rejected,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Detalhes do evento
  // ---------------------------------------------------------------------

  void _showDetails(RequestModel r) {
    final vehicle = RequestController.instance.vehicleOf(r);
    final period = r.returnPeriod;
    final returnText = r.returnDate == null
        ? '—'
        : '${_pad(r.returnDate!.day)}/${_pad(r.returnDate!.month)}/'
              '${r.returnDate!.year}'
              '${period != null ? ' · ${period.label} (${period.description})' : ''}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: r.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      r.status.label,
                      style: TextStyle(
                        color: r.status.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Solicitação #${r.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Viagem a ${r.destination}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _detail('Solicitante', r.requester),
              _detail('Motivo', r.reason),
              _detail(
                'Veículo',
                vehicle != null
                    ? '${vehicle.model} · ${vehicle.plate}'
                    : (r.status == RequestStatus.pendente
                          ? 'A definir pelo aprovador'
                          : '—'),
              ),
              _detail('Passageiros', '${r.passengers}'),
              _detail('Saída', _fmtDateTime(r.departure)),
              _detail('Retorno', returnText),
              if (r.checkOutAt != null)
                _detail('Retirado em', _fmtDateTime(r.checkOutAt)),
              if (r.checkInAt != null)
                _detail('Devolvido em', _fmtDateTime(r.checkInAt)),
              if (r.distanceTravelled != null)
                _detail('Distância', '${r.distanceTravelled} km'),
              if (r.checkOutNotes != null)
                _detail('Obs. retirada', r.checkOutNotes!),
              if (r.checkInNotes != null)
                _detail('Obs. devolução', r.checkInNotes!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pedaço de uma reserva dentro de um dia específico da grade.
class _Segment {
  final RequestModel request;
  final DateTimeRange range; // intervalo completo da reserva
  final DateTime start; // início recortado no dia
  final DateTime end; // fim recortado no dia
  final double top;
  final double height;
  int lane = 0;
  int lanes = 1;

  _Segment(
    this.request,
    this.range,
    this.start,
    this.end,
    this.top,
    this.height,
  );
}

/// Desenha uma borda tracejada arredondada (visual da pré-reserva).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  _DashedBorderPainter(
    this.color, {
    this.radius = 4,
    this.dash = 4,
    this.gap = 3,
    this.strokeWidth = 1.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// Resultado do seletor de veículos.
class _VehicleSelection {
  final bool showAll;
  final Set<int> ids;

  const _VehicleSelection(this.showAll, this.ids);
}

/// Painel de seleção de veículos com busca — escala para frotas grandes.
class _VehiclePickerSheet extends StatefulWidget {
  final List<VehicleModel> vehicles;
  final bool showAll;
  final Set<int> selected;

  const _VehiclePickerSheet({
    required this.vehicles,
    required this.showAll,
    required this.selected,
  });

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  late bool _all = widget.showAll;
  late final Set<int> _ids = {...widget.selected};
  String _query = '';

  List<VehicleModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vehicles;
    return widget.vehicles
        .where(
          (v) =>
              v.model.toLowerCase().contains(q) ||
              v.plate.toLowerCase().contains(q),
        )
        .toList();
  }

  bool _isChecked(int id) => _all || _ids.contains(id);

  void _toggle(int id) => setState(() {
    if (_all) {
      // Estava em "Todos": passa a ser todos menos o desmarcado.
      _all = false;
      _ids
        ..clear()
        ..addAll(widget.vehicles.map((v) => v.id))
        ..remove(id);
    } else if (!_ids.remove(id)) {
      _ids.add(id);
    }
  });

  String get _summary {
    if (_all) return 'Todos';
    if (_ids.isEmpty) return 'Nenhum';
    return '${_ids.length} selecionado(s)';
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final list = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            // Alça do painel
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Selecionar veículos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    _summary,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (text) => setState(() => _query = text),
                decoration: InputDecoration(
                  hintText: 'Buscar por modelo ou placa',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _all = false;
                      _ids.clear();
                    }),
                    child: const Text('Nenhum'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _all = true;
                      _ids.clear();
                    }),
                    child: const Text('Todos'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum veículo encontrado.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final v = list[index];
                        return CheckboxListTile(
                          value: _isChecked(v.id),
                          onChanged: (_) => _toggle(v.id),
                          activeColor: AppColors.primary,
                          dense: true,
                          secondary: Icon(
                            v.type.icon,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            v.model,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${v.plate} · ${v.seats} lugares'),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_VehicleSelection(_all, _all ? <int>{} : {..._ids})),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Aplicar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
