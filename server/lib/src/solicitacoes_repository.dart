import 'package:frota_core/frota_core.dart';
import 'package:postgres/postgres.dart';

/// Acesso à tabela `solicitacoes`. Só SQL e conversão linha → [RequestModel].
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
