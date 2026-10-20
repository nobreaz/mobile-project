import 'package:frota_core/frota_core.dart';
import 'package:postgres/postgres.dart';

/// Fuso da empresa. "Devolver até 12h" é 12h no horário de Brasília,
/// mesmo que o servidor rode em UTC (como na maioria das hospedagens).
const companyTimeZone = 'America/Sao_Paulo';

/// Intervalo que a solicitação [alias] ocupa na agenda (mesma regra do app):
/// - em uso, começa na retirada real (pode ter sido antes da saída prevista);
/// - em uso e com a devolução atrasada, ocupa até o check-in (sem fim).
String occupiedRangeSql(String alias) =>
    '''
    tstzrange(
      CASE WHEN $alias.status = 'emUso'
           THEN least(coalesce($alias.check_out_em, $alias.saida), $alias.saida)
           ELSE $alias.saida END,
      CASE WHEN $alias.status = 'emUso' AND $alias.prazo_retorno < now()
           THEN 'infinity'::timestamptz
           ELSE $alias.prazo_retorno END,
      '[)')''';

/// Solicitação que voltou para Pendente porque o veículo deixou de atendê-la.
typedef ReleasedRequest = ({int id, int requesterId, String destination});

/// Acesso à tabela `solicitacoes`. Só SQL e conversão linha → [RequestModel];
/// regras de negócio ficam no `FrotaService` e no frota_core.
class SolicitacoesRepository {
  SolicitacoesRepository(this._db);

  final Session _db;

  // Nomes do solicitante e do aprovador vêm de `usuarios` (dois joins).
  static const _select = '''
    SELECT s.id, s.solicitante_id, u.nome AS solicitante,
           s.motivo, s.destino, s.passageiros,
           s.saida, s.data_retorno, s.periodo_retorno::text AS periodo_retorno,
           s.status::text AS status, s.veiculo_id, s.justificativa_recusa,
           s.km_saida, s.km_retorno, s.check_out_em, s.check_in_em,
           s.obs_check_out, s.obs_check_in,
           s.aprovador_id, a.nome AS aprovador, s.decidido_em
    FROM solicitacoes s
    JOIN usuarios u ON u.id = s.solicitante_id
    LEFT JOIN usuarios a ON a.id = s.aprovador_id''';

  /// Colunas que podem ser alteradas por [update], com o tipo SQL de cada uma.
  static const editableColumns = {
    'motivo': 'text',
    'destino': 'text',
    'passageiros': 'int',
    'saida': 'timestamptz',
    'data_retorno': 'date',
    'periodo_retorno': 'periodo_retorno',
    'prazo_retorno': 'timestamptz',
    'status': 'status_solicitacao',
    'veiculo_id': 'bigint',
    'justificativa_recusa': 'text',
    'km_saida': 'int',
    'km_retorno': 'int',
    'check_out_em': 'timestamptz',
    'check_in_em': 'timestamptz',
    'obs_check_out': 'text',
    'obs_check_in': 'text',
    'aprovador_id': 'bigint',
    'decidido_em': 'timestamptz',
  };

  /// [forUpdate] trava a solicitação até o fim da transação (usar dentro
  /// de `runTx`), para duas ações sobre ela não se atropelarem.
  Future<RequestModel?> findById(int id, {bool forUpdate = false}) async {
    final result = await _db.execute(
      Sql.named(
        '$_select WHERE s.id = @id${forUpdate ? ' FOR UPDATE OF s' : ''}',
      ),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : _fromRow(result.first);
  }

  /// Lista com filtros opcionais, mais recentes primeiro
  /// (decididas pela data da decisão; pendentes pela data de criação).
  Future<List<RequestModel>> list({
    Set<RequestStatus>? statuses,
    int? requesterId,
    int? approverId,
  }) async {
    final where = <String>[];
    final params = <String, Object?>{};

    if (statuses != null && statuses.isNotEmpty) {
      where.add('s.status::text = ANY(@statuses)');
      params['statuses'] = TypedValue(
        Type.textArray,
        [for (final s in statuses) s.name],
      );
    }
    if (requesterId != null) {
      where.add('s.solicitante_id = @requesterId');
      params['requesterId'] = requesterId;
    }
    if (approverId != null) {
      where.add('s.aprovador_id = @approverId');
      params['approverId'] = approverId;
    }

    final result = await _db.execute(
      Sql.named(
        '$_select '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY coalesce(s.decidido_em, s.criado_em) DESC, s.id DESC',
      ),
      parameters: params,
    );
    return result.map(_fromRow).toList();
  }

  /// Prazo exato de devolução: [returnDate] às 12h (manhã) ou 18h (tarde)
  /// no fuso da empresa. Mesma regra de `RequestModel.returnDeadline`.
  Future<DateTime> deadline(DateTime returnDate, ReturnPeriod period) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT (@date::date + make_interval(hours => @hour::int)) '
        'AT TIME ZONE @zone::text',
      ),
      parameters: {
        'date': formatDate(returnDate),
        'hour': period.endHour,
        'zone': companyTimeZone,
      },
    );
    return (result.first.first! as DateTime).toUtc();
  }

  /// Saída e prazo de devolução gravados (o prazo não está no modelo).
  Future<({DateTime start, DateTime end})> periodOf(int id) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT saida, prazo_retorno FROM solicitacoes WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    final row = result.single;
    return (start: row[0]! as DateTime, end: row[1]! as DateTime);
  }

  /// RN 4.4: o usuário já tem outra solicitação ativa (pendente, aprovada ou
  /// em uso) que se sobrepõe a [start]–[end]?
  Future<bool> userHasConflict({
    required int userId,
    required DateTime start,
    required DateTime end,
    int? ignoreRequestId,
  }) => _exists(
    '''
    SELECT 1 FROM solicitacoes o
    WHERE o.solicitante_id = @owner
      AND o.id <> @ignore
      AND o.status IN ('pendente', 'aprovada', 'emUso')
      AND ${occupiedRangeSql('o')}
          && tstzrange(@start::timestamptz, @end::timestamptz, '[)')''',
    {
      'owner': userId,
      'ignore': ignoreRequestId ?? 0,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    },
  );

  /// RN 4.3: o veículo está livre (sem reserva aprovada ou em uso) no
  /// período [start]–[end] inteiro?
  Future<bool> vehicleIsFree({
    required int vehicleId,
    required DateTime start,
    required DateTime end,
    int? ignoreRequestId,
  }) async => !await _exists(
    '''
    SELECT 1 FROM solicitacoes o
    WHERE o.veiculo_id = @vehicle
      AND o.id <> @ignore
      AND o.status IN ('aprovada', 'emUso')
      AND ${occupiedRangeSql('o')}
          && tstzrange(@start::timestamptz, @end::timestamptz, '[)')''',
    {
      'vehicle': vehicleId,
      'ignore': ignoreRequestId ?? 0,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    },
  );

  /// Grava uma nova solicitação (sempre Pendente). Devolve o id.
  Future<int> insert({
    required int requesterId,
    required String reason,
    required String destination,
    required int passengers,
    required DateTime departure,
    required DateTime returnDate,
    required ReturnPeriod returnPeriod,
    required DateTime deadline,
  }) async {
    final result = await _db.execute(
      Sql.named('''
        INSERT INTO solicitacoes (
          solicitante_id, motivo, destino, passageiros,
          saida, data_retorno, periodo_retorno, prazo_retorno
        ) VALUES (
          @requester, @reason, @destination, @passengers,
          @departure::timestamptz, @returnDate::date,
          @period::periodo_retorno, @deadline::timestamptz
        )
        RETURNING id'''),
      parameters: {
        'requester': requesterId,
        'reason': reason,
        'destination': destination,
        'passengers': passengers,
        'departure': departure.toUtc().toIso8601String(),
        'returnDate': formatDate(returnDate),
        'period': returnPeriod.name,
        'deadline': deadline.toUtc().toIso8601String(),
      },
    );
    return result.single.first! as int;
  }

  /// Altera só as colunas recebidas em [changes] (nomes de [editableColumns]).
  /// `DateTime` vira dia (`date`) ou momento UTC (`timestamptz`) conforme
  /// a coluna.
  Future<void> update(int id, Map<String, Object?> changes) async {
    if (changes.isEmpty) return;

    final sets = <String>[];
    final params = <String, Object?>{'id': id};
    for (final MapEntry(key: column, :value) in changes.entries) {
      final type = editableColumns[column];
      if (type == null) throw ArgumentError('Coluna não editável: $column');
      sets.add('$column = @$column::$type');
      params[column] = switch (value) {
        final DateTime d when type == 'date' => formatDate(d),
        final DateTime d => d.toUtc().toIso8601String(),
        final Enum e => e.name,
        _ => value,
      };
    }

    await _db.execute(
      Sql.named('UPDATE solicitacoes SET ${sets.join(', ')} WHERE id = @id'),
      parameters: params,
    );
  }

  /// Devolve para Pendente as reservas APROVADAS do veículo (ainda não
  /// retiradas), apagando veículo e decisão. Com [seats], só as que têm
  /// mais passageiros que isso (o veículo perdeu lugares).
  Future<List<ReleasedRequest>> releaseApproved(
    int vehicleId, {
    int? seats,
  }) async {
    final result = await _db.execute(
      Sql.named('''
        UPDATE solicitacoes
        SET status = 'pendente', veiculo_id = NULL,
            aprovador_id = NULL, decidido_em = NULL
        WHERE veiculo_id = @vehicle AND status = 'aprovada'
          ${seats == null ? '' : 'AND passageiros > @seats'}
        RETURNING id, solicitante_id, destino'''),
      parameters: {'vehicle': vehicleId, 'seats': ?seats},
    );
    return [
      for (final row in result)
        (
          id: row[0]! as int,
          requesterId: row[1]! as int,
          destination: row[2]! as String,
        ),
    ];
  }

  Future<bool> _exists(String sql, Map<String, Object?> parameters) async {
    final result = await _db.execute(
      Sql.named('SELECT EXISTS ($sql)'),
      parameters: parameters,
    );
    return result.single.first! as bool;
  }

  static RequestModel _fromRow(ResultRow row) {
    final m = row.toColumnMap();
    DateTime? local(String key) => (m[key] as DateTime?)?.toLocal();
    final returnDate = m['data_retorno'] as DateTime?;

    return RequestModel(
      id: m['id'] as int,
      requesterId: m['solicitante_id'] as int,
      requester: m['solicitante'] as String,
      reason: m['motivo'] as String,
      destination: m['destino'] as String,
      passengers: m['passageiros'] as int,
      departure: local('saida'),
      // `date` chega como meia-noite UTC; guardamos só o dia.
      returnDate: returnDate == null
          ? null
          : DateTime(returnDate.year, returnDate.month, returnDate.day),
      returnPeriod: ReturnPeriod.values.byName(m['periodo_retorno'] as String),
      status: RequestStatus.values.byName(m['status'] as String),
      vehicleId: m['veiculo_id'] as int?,
      rejectionReason: m['justificativa_recusa'] as String?,
      departureMileage: m['km_saida'] as int?,
      returnMileage: m['km_retorno'] as int?,
      checkOutAt: local('check_out_em'),
      checkInAt: local('check_in_em'),
      checkOutNotes: m['obs_check_out'] as String?,
      checkInNotes: m['obs_check_in'] as String?,
      approverId: m['aprovador_id'] as int?,
      approverName: m['aprovador'] as String?,
      decidedAt: local('decidido_em'),
    );
  }
}
