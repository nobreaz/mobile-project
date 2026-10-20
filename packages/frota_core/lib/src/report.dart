import 'request.dart';
import 'user.dart';
import 'vehicle.dart';

/// Relatórios da frota (tela "Ver Relatórios", Aprovador e Administrador).
///
/// O servidor monta o [FleetReport] com consultas agregadas no banco
/// (`GET /relatorios`) e o app só desenha. Os alertas de veículo e de CNH
/// usam as mesmas regras de vencimento do resto do app.

/// O que motivou um alerta da seção "Precisa de atenção".
enum AlertKind {
  licenciamento,
  seguro,
  revisao,
  manutencao,
  cnh,
  devolucaoAtrasada,
  saidaSemAprovacao,
}

/// Um item da seção "Precisa de atenção".
class ReportAlert {
  const ReportAlert({
    required this.kind,
    required this.critical,
    required this.title,
    required this.message,
  });

  factory ReportAlert.fromJson(Map<String, dynamic> json) => ReportAlert(
    kind: AlertKind.values.byName(json['kind'] as String),
    critical: json['critical'] as bool,
    title: json['title'] as String,
    message: json['message'] as String,
  );

  final AlertKind kind;

  /// Já venceu / já atrasou (vermelho). Senão, está para vencer (amarelo).
  final bool critical;

  /// Quem: "Gol · ABC1D23" ou o nome do motorista.
  final String title;

  /// O quê: "Seguro vence em 02/11/2026".
  final String message;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'critical': critical,
    'title': title,
    'message': message,
  };
}

String _br(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Documentos vencidos ou vencendo, revisão próxima e manutenção.
/// Veículo inativo não gera alerta (está fora da frota).
List<ReportAlert> vehicleAlerts(VehicleModel v, {DateTime? today}) {
  if (v.status == VehicleStatus.inativo) return const [];
  final title = '${v.model} · ${v.plate}';
  final alerts = <ReportAlert>[];

  void document(AlertKind kind, String name, DateTime? expiry) {
    final status = expiryStatusOf(expiry, today: today);
    if (status == ExpiryStatus.vencido) {
      alerts.add(
        ReportAlert(
          kind: kind,
          critical: true,
          title: title,
          message: '$name vencido em ${_br(expiry!)}',
        ),
      );
    } else if (status == ExpiryStatus.vencendo) {
      alerts.add(
        ReportAlert(
          kind: kind,
          critical: false,
          title: title,
          message: '$name vence em ${_br(expiry!)}',
        ),
      );
    }
  }

  document(AlertKind.licenciamento, 'Licenciamento/IPVA', v.licensingExpiry);
  document(AlertKind.seguro, 'Seguro', v.insuranceExpiry);

  final next = v.nextServiceMileage;
  switch (v.serviceStatus) {
    case ExpiryStatus.vencido:
      alerts.add(
        ReportAlert(
          kind: AlertKind.revisao,
          critical: true,
          title: title,
          message:
              'Revisão atrasada: era aos $next km, está com ${v.mileage} km',
        ),
      );
    case ExpiryStatus.vencendo:
      alerts.add(
        ReportAlert(
          kind: AlertKind.revisao,
          critical: false,
          title: title,
          message: 'Revisão em ${next! - v.mileage} km (aos $next km)',
        ),
      );
    case ExpiryStatus.valido:
    case ExpiryStatus.naoInformado:
      break;
  }

  if (v.status == VehicleStatus.emManutencao) {
    alerts.add(
      ReportAlert(
        kind: AlertKind.manutencao,
        critical: false,
        title: title,
        message: 'Em manutenção (fora da agenda)',
      ),
    );
  }
  return alerts;
}

/// CNH vencida, vencendo ou não informada de quem pode solicitar veículo
/// (perfil Padrão ativo). Sem CNH válida ele não consegue pedir carro.
ReportAlert? driverAlert(UserModel u) {
  if (!u.active || !u.profile.canRequest) return null;
  return switch (u.cnhStatus) {
    CnhStatus.vencida => ReportAlert(
      kind: AlertKind.cnh,
      critical: true,
      title: u.name,
      message: 'CNH vencida em ${_br(u.cnhExpiry!)}: não pode solicitar',
    ),
    CnhStatus.vencendo => ReportAlert(
      kind: AlertKind.cnh,
      critical: false,
      title: u.name,
      message: 'CNH vence em ${_br(u.cnhExpiry!)}',
    ),
    CnhStatus.naoInformada => ReportAlert(
      kind: AlertKind.cnh,
      critical: false,
      title: u.name,
      message: 'CNH não cadastrada: não pode solicitar',
    ),
    CnhStatus.valida => null,
  };
}

/// Uma linha das tabelas: usuário, veículo ou setor.
class RankingEntry {
  const RankingEntry({
    required this.label,
    required this.trips,
    this.id,
    this.detail,
    this.km = 0,
    this.lateReturns = 0,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
    id: json['id'] as int?,
    label: json['label'] as String,
    detail: json['detail'] as String?,
    trips: json['trips'] as int,
    km: json['km'] as int? ?? 0,
    lateReturns: json['lateReturns'] as int? ?? 0,
  );

  final int? id;

  /// Nome do usuário, modelo do veículo ou setor.
  final String label;

  /// Complemento: setor do usuário ou placa do veículo.
  final String? detail;

  final int trips;

  /// Km rodados nas viagens já devolvidas (usado na tabela de veículos).
  final int km;

  /// Devoluções feitas depois do prazo.
  final int lateReturns;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'detail': detail,
    'trips': trips,
    'km': km,
    'lateReturns': lateReturns,
  };
}

/// Viagens de uma semana ou mês (gráfico de evolução).
class TrendPoint {
  const TrendPoint({required this.start, required this.trips});

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    start: DateTime.parse(json['start'] as String),
    trips: json['trips'] as int,
  );

  /// Primeiro dia da semana (segunda) ou do mês.
  final DateTime start;
  final int trips;

  Map<String, dynamic> toJson() => {'start': formatDate(start), 'trips': trips};
}

/// Decisões de um aprovador no período.
class ApproverStats {
  const ApproverStats({
    required this.id,
    required this.name,
    required this.approved,
    required this.rejected,
  });

  factory ApproverStats.fromJson(Map<String, dynamic> json) => ApproverStats(
    id: json['id'] as int,
    name: json['name'] as String,
    approved: json['approved'] as int,
    rejected: json['rejected'] as int,
  );

  final int id;
  final String name;
  final int approved;
  final int rejected;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'approved': approved,
    'rejected': rejected,
  };
}

/// Agrupamento do gráfico de evolução.
enum TrendGranularity { week, month }

/// Tudo o que a tela de relatórios mostra, para os últimos [days] dias.
///
/// "Viagem" = solicitação retirada (check-out) dentro do período, em uso
/// ou já finalizada. Km só conta as finalizadas (precisam da km de volta).
/// Os números do fluxo de pedidos (status e aprovação) contam as
/// solicitações CRIADAS no período.
class FleetReport {
  const FleetReport({
    required this.days,
    required this.granularity,
    required this.trips,
    required this.finishedTrips,
    required this.lateReturns,
    required this.requests,
    required this.statuses,
    required this.trend,
    required this.users,
    required this.vehicles,
    required this.departments,
    required this.approvers,
    required this.alerts,
  });

  factory FleetReport.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final item in json[key] as List) parse(item as Map<String, dynamic>),
    ];

    return FleetReport(
      days: json['days'] as int,
      granularity: TrendGranularity.values.byName(
        json['granularity'] as String,
      ),
      trips: json['trips'] as int,
      finishedTrips: json['finishedTrips'] as int,
      lateReturns: json['lateReturns'] as int,
      requests: json['requests'] as int,
      statuses: {
        for (final e in (json['statuses'] as Map<String, dynamic>).entries)
          RequestStatus.values.byName(e.key): e.value as int,
      },
      trend: list('trend', TrendPoint.fromJson),
      users: list('users', RankingEntry.fromJson),
      vehicles: list('vehicles', RankingEntry.fromJson),
      departments: list('departments', RankingEntry.fromJson),
      approvers: list('approvers', ApproverStats.fromJson),
      alerts: list('alerts', ReportAlert.fromJson),
    );
  }

  final int days;
  final TrendGranularity granularity;

  /// Viagens retiradas no período.
  final int trips;

  /// Viagens já devolvidas e quantas delas depois do prazo.
  final int finishedTrips;
  final int lateReturns;

  /// Solicitações criadas no período.
  final int requests;

  /// Solicitações criadas no período, por status atual.
  final Map<RequestStatus, int> statuses;

  final List<TrendPoint> trend;

  /// Quem mais viajou: mais viagens primeiro.
  final List<RankingEntry> users;

  /// Toda a frota ativa, inclusive os sem viagem (parados), no fim.
  final List<RankingEntry> vehicles;
  final List<RankingEntry> departments;
  final List<ApproverStats> approvers;

  /// Críticos primeiro.
  final List<ReportAlert> alerts;

  /// Período dos dados, para títulos: "30 dias", "12 meses".
  String get periodLabel => days == 365 ? '12 meses' : '$days dias';

  int get approved =>
      (statuses[RequestStatus.aprovada] ?? 0) +
      (statuses[RequestStatus.emUso] ?? 0) +
      (statuses[RequestStatus.finalizada] ?? 0);

  int get rejected => statuses[RequestStatus.recusada] ?? 0;

  /// Aprovadas entre as decididas (0 a 1). `null` sem decisões.
  double? get approvalRate {
    final decided = approved + rejected;
    return decided == 0 ? null : approved / decided;
  }

  /// Devolvidas no prazo (0 a 1). `null` sem viagens finalizadas.
  double? get onTimeRate =>
      finishedTrips == 0 ? null : (finishedTrips - lateReturns) / finishedTrips;

  Map<String, dynamic> toJson() => {
    'days': days,
    'granularity': granularity.name,
    'trips': trips,
    'finishedTrips': finishedTrips,
    'lateReturns': lateReturns,
    'requests': requests,
    'statuses': {for (final e in statuses.entries) e.key.name: e.value},
    'trend': [for (final t in trend) t.toJson()],
    'users': [for (final e in users) e.toJson()],
    'vehicles': [for (final e in vehicles) e.toJson()],
    'departments': [for (final e in departments) e.toJson()],
    'approvers': [for (final a in approvers) a.toJson()],
    'alerts': [for (final a in alerts) a.toJson()],
  };
}
