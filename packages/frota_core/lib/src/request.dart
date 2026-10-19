/// Status possíveis de uma solicitação de agendamento.
///
/// Ciclo previsto na regra 4.2 do documento:
/// Pendente → Aprovada → Em uso → Finalizada
/// (ou, a partir de Pendente: Negada / Cancelada)
enum RequestStatus {
  pendente,
  aprovada,
  emUso,
  finalizada,
  recusada,
  cancelada,
}

extension RequestStatusX on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pendente:
        return 'Pendente';
      case RequestStatus.aprovada:
        return 'Aprovada';
      case RequestStatus.emUso:
        return 'Em uso';
      case RequestStatus.finalizada:
        return 'Finalizada';
      case RequestStatus.recusada:
        return 'Recusada';
      case RequestStatus.cancelada:
        return 'Cancelada';
    }
  }

  /// Ocupa a agenda do usuário (regra 4.4).
  bool get isActive =>
      this == RequestStatus.pendente ||
      this == RequestStatus.aprovada ||
      this == RequestStatus.emUso;

  /// Ocupa a agenda do veículo alocado (regra 4.3).
  bool get holdsVehicle =>
      this == RequestStatus.aprovada || this == RequestStatus.emUso;
}

/// Período do dia em que o veículo será devolvido.
enum ReturnPeriod { manha, tarde }

extension ReturnPeriodX on ReturnPeriod {
  String get label {
    switch (this) {
      case ReturnPeriod.manha:
        return 'Manhã';
      case ReturnPeriod.tarde:
        return 'Tarde';
    }
  }

  /// Horário limite de devolução de cada período.
  int get endHour {
    switch (this) {
      case ReturnPeriod.manha:
        return 12;
      case ReturnPeriod.tarde:
        return 18;
    }
  }

  String get description => 'até ${endHour}h';
}

/// Dois intervalos `[aStart, aEnd)` e `[bStart, bEnd)` se sobrepõem?
/// Base das regras 4.3 (veículo) e 4.4 (usuário). Encostar não conta:
/// uma devolução às 12h não conflita com uma saída às 12h.
bool periodsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) => aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Representa uma solicitação de agendamento de veículo.
/// (Entidade "Solicitação de agendamento" — seção 5.3 do documento.)
class RequestModel {
  final int id;

  /// Usuário que abriu a solicitação (id + nome).
  final int requesterId;
  final String requester;

  // Campos editáveis antes do check-out.
  String reason;
  String destination;
  int passengers;
  DateTime? departure;
  DateTime? returnDate;
  ReturnPeriod? returnPeriod;

  RequestStatus status;

  /// Veículo alocado pelo aprovador (item 5.3.4 / regra 4.1.3).
  int? vehicleId;

  /// Justificativa obrigatória em caso de recusa (regra 4.7).
  String? rejectionReason;

  /// Quilometragem de saída e de retorno (item 5.3.5 / regra 4.8).
  int? departureMileage;
  int? returnMileage;

  /// Momentos reais de retirada e devolução.
  DateTime? checkOutAt;
  DateTime? checkInAt;

  /// Observações registradas na retirada e na devolução.
  String? checkOutNotes;
  String? checkInNotes;

  /// Aprovador que decidiu (aprovou ou recusou) e quando.
  /// Nulos enquanto pendente; apagados se a solicitação voltar a pendente.
  int? approverId;
  String? approverName;
  DateTime? decidedAt;

  RequestModel({
    required this.id,
    required this.reason,
    required this.destination,
    required this.passengers,
    this.requesterId = 1,
    this.requester = 'Nome Sobrenome',
    this.departure,
    this.returnDate,
    this.returnPeriod,
    this.status = RequestStatus.pendente,
    this.vehicleId,
    this.rejectionReason,
    this.departureMileage,
    this.returnMileage,
    this.checkOutAt,
    this.checkInAt,
    this.checkOutNotes,
    this.checkInNotes,
    this.approverId,
    this.approverName,
    this.decidedAt,
  });

  /// Formato JSON trocado entre a API e o app.
  /// Momentos (saída, check-out...) vão em ISO 8601 UTC e voltam no fuso
  /// local; a data de retorno é só o dia (`AAAA-MM-DD`).
  factory RequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? instant(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.parse(v).toLocal();
    }

    final returnDate = json['returnDate'] as String?;
    final period = json['returnPeriod'] as String?;
    return RequestModel(
      id: json['id'] as int,
      requesterId: json['requesterId'] as int,
      requester: json['requester'] as String,
      reason: json['reason'] as String,
      destination: json['destination'] as String,
      passengers: json['passengers'] as int,
      departure: instant('departure'),
      returnDate: returnDate == null ? null : DateTime.parse(returnDate),
      returnPeriod: period == null ? null : ReturnPeriod.values.byName(period),
      status: RequestStatus.values.byName(json['status'] as String),
      vehicleId: json['vehicleId'] as int?,
      rejectionReason: json['rejectionReason'] as String?,
      departureMileage: json['departureMileage'] as int?,
      returnMileage: json['returnMileage'] as int?,
      checkOutAt: instant('checkOutAt'),
      checkInAt: instant('checkInAt'),
      checkOutNotes: json['checkOutNotes'] as String?,
      checkInNotes: json['checkInNotes'] as String?,
      approverId: json['approverId'] as int?,
      approverName: json['approverName'] as String?,
      decidedAt: instant('decidedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    String? instant(DateTime? d) => d?.toUtc().toIso8601String();
    final date = returnDate;
    return {
      'id': id,
      'requesterId': requesterId,
      'requester': requester,
      'reason': reason,
      'destination': destination,
      'passengers': passengers,
      'departure': instant(departure),
      'returnDate': date == null
          ? null
          : '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}',
      'returnPeriod': returnPeriod?.name,
      'status': status.name,
      'vehicleId': vehicleId,
      'rejectionReason': rejectionReason,
      'departureMileage': departureMileage,
      'returnMileage': returnMileage,
      'checkOutAt': instant(checkOutAt),
      'checkInAt': instant(checkInAt),
      'checkOutNotes': checkOutNotes,
      'checkInNotes': checkInNotes,
      'approverId': approverId,
      'approverName': approverName,
      'decidedAt': instant(decidedAt),
    };
  }

  /// Registra a decisão do aprovador (aprovação ou recusa).
  void recordDecision({required int approverId, required String approverName}) {
    this.approverId = approverId;
    this.approverName = approverName;
    decidedAt = DateTime.now();
  }

  /// Volta para pendente: a decisão anterior deixa de valer.
  void clearDecision() {
    approverId = null;
    approverName = null;
    decidedAt = null;
  }

  /// Já passou pela aprovação (aprovada, em uso ou finalizada).
  bool get wasApproved =>
      status == RequestStatus.aprovada ||
      status == RequestStatus.emUso ||
      status == RequestStatus.finalizada;

  /// Prazo exato de devolução: data de retorno + horário do período.
  DateTime? get returnDeadline {
    final date = returnDate;
    if (date == null) return null;
    final hour = (returnPeriod ?? ReturnPeriod.tarde).endHour;
    return DateTime(date.year, date.month, date.day, hour);
  }

  /// Pode ser editada? Somente antes do check-out.
  bool get canEdit =>
      status == RequestStatus.pendente || status == RequestStatus.aprovada;

  /// Data de saída passou e o veículo não foi retirado.
  bool get isCheckOutLate =>
      status == RequestStatus.aprovada &&
      departure != null &&
      departure!.isBefore(DateTime.now());

  /// Prazo de retorno passou e o veículo continua em uso.
  bool get isReturnLate =>
      status == RequestStatus.emUso &&
      returnDeadline != null &&
      returnDeadline!.isBefore(DateTime.now());

  /// Viagem finalizada, mas devolvida depois do prazo.
  bool get wasReturnedLate {
    final deadline = returnDeadline;
    final at = checkInAt;
    return status == RequestStatus.finalizada &&
        deadline != null &&
        at != null &&
        at.isAfter(deadline);
  }

  /// Distância percorrida na viagem, quando já finalizada.
  int? get distanceTravelled {
    if (departureMileage == null || returnMileage == null) return null;
    return returnMileage! - departureMileage!;
  }
}
