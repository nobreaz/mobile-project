import 'package:frota_core/frota_core.dart';
import 'package:frota_server/src/solicitacoes_repository.dart';
import 'package:postgres/postgres.dart';

/// Acesso à tabela `veiculos`. Só SQL e conversão linha → [VehicleModel];
/// regras de negócio ficam no `FrotaService` e no frota_core.
class VeiculosRepository {
  VeiculosRepository(this._db);

  final Session _db;

  static const _columns = '''
    v.id, v.placa, v.chassi, v.modelo, v.cor, v.ano, v.lugares,
    v.quilometragem, v.tipo::text AS tipo, v.status::text AS status,
    v.vencimento_licenciamento, v.vencimento_seguro''';

  /// Colunas que podem ser alteradas por [update], com o tipo SQL de cada uma.
  static const editableColumns = {
    'placa': 'text',
    'chassi': 'text',
    'modelo': 'text',
    'cor': 'text',
    'ano': 'int',
    'lugares': 'int',
    'quilometragem': 'int',
    'tipo': 'tipo_veiculo',
    'status': 'status_veiculo',
    'vencimento_licenciamento': 'date',
    'vencimento_seguro': 'date',
  };

  /// [forUpdate] trava a linha até o fim da transação (usar dentro de
  /// `runTx`): duas aprovações do mesmo veículo ao mesmo tempo esperam
  /// uma pela outra em vez de passarem juntas.
  Future<VehicleModel?> findById(int id, {bool forUpdate = false}) => _one(
    'SELECT $_columns FROM veiculos v WHERE v.id = @id'
    '${forUpdate ? ' FOR UPDATE' : ''}',
    {'id': id},
  );

  /// A frota inteira: inativos por último, depois por modelo e placa.
  Future<List<VehicleModel>> list() async {
    final result = await _db.execute(
      'SELECT $_columns FROM veiculos v '
      "ORDER BY v.status = 'inativo', v.modelo, v.placa",
    );
    return result.map(_fromRow).toList();
  }

  /// RN 4.1: veículos que podem atender o período [start]–[end] com
  /// [passengers] pessoas. Fora de manutenção/inativos, com lugares
  /// suficientes e livres na agenda; os de menor quilometragem primeiro.
  /// [ignoreRequestId]: a própria solicitação (ao reavaliar uma reserva).
  Future<List<VehicleModel>> eligible({
    required int passengers,
    required DateTime start,
    required DateTime end,
    int? ignoreRequestId,
  }) async {
    final result = await _db.execute(
      Sql.named('''
        SELECT $_columns FROM veiculos v
        WHERE v.status NOT IN ('emManutencao', 'inativo')
          AND v.lugares >= @passengers
          AND NOT EXISTS (
            SELECT 1 FROM solicitacoes o
            WHERE o.veiculo_id = v.id
              AND o.id <> @ignore
              AND o.status IN ('aprovada', 'emUso')
              AND ${occupiedRangeSql('o')}
                  && tstzrange(@start::timestamptz, @end::timestamptz, '[)')
          )
        ORDER BY v.quilometragem, v.id'''),
      parameters: {
        'passengers': passengers,
        'ignore': ignoreRequestId ?? 0,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    );
    return result.map(_fromRow).toList();
  }

  /// Maior lotação entre os veículos que podem ser agendados
  /// (limite de passageiros de uma solicitação). `null` se não houver.
  Future<int?> maxSeats() async {
    final result = await _db.execute(
      'SELECT max(lugares) FROM veiculos '
      "WHERE status NOT IN ('emManutencao', 'inativo')",
    );
    return result.first.first as int?;
  }

  Future<VehicleModel> insert(VehicleModel v) async {
    final created = await _one(
      '''
      INSERT INTO veiculos AS v (
        placa, chassi, modelo, cor, ano, lugares, quilometragem,
        tipo, status, vencimento_licenciamento, vencimento_seguro
      ) VALUES (
        @placa, @chassi, @modelo, @cor, @ano, @lugares, @quilometragem,
        @tipo::tipo_veiculo, @status::status_veiculo,
        @licenciamento::date, @seguro::date
      )
      RETURNING $_columns''',
      {
        'placa': v.plate,
        'chassi': v.chassis,
        'modelo': v.model,
        'cor': v.color,
        'ano': v.year,
        'lugares': v.seats,
        'quilometragem': v.mileage,
        'tipo': v.type.name,
        'status': v.status.name,
        'licenciamento': formatDate(v.licensingExpiry!),
        'seguro': formatDate(v.insuranceExpiry!),
      },
    );
    return created!;
  }

  /// Altera só as colunas recebidas em [changes] (nomes de [editableColumns]).
  /// Devolve o veículo atualizado ou `null` se o id não existir.
  Future<VehicleModel?> update(int id, Map<String, Object?> changes) {
    if (changes.isEmpty) return findById(id);

    final sets = <String>[];
    for (final column in changes.keys) {
      final type = editableColumns[column];
      if (type == null) throw ArgumentError('Coluna não editável: $column');
      sets.add('$column = @$column::$type');
    }

    return _one(
      'UPDATE veiculos AS v SET ${sets.join(', ')} WHERE v.id = @id '
      'RETURNING $_columns',
      {
        ...changes.map(
          (k, v) => MapEntry(k, v is DateTime ? formatDate(v) : v),
        ),
        'id': id,
      },
    );
  }

  Future<VehicleModel?> _one(
    String sql,
    Map<String, Object?> parameters,
  ) async {
    final result = await _db.execute(Sql.named(sql), parameters: parameters);
    return result.isEmpty ? null : _fromRow(result.first);
  }

  static VehicleModel _fromRow(ResultRow row) {
    final m = row.toColumnMap();
    // `date` chega como meia-noite UTC; guardamos só o dia.
    DateTime? day(String key) {
      final d = m[key] as DateTime?;
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    return VehicleModel(
      id: m['id'] as int,
      plate: m['placa'] as String,
      chassis: m['chassi'] as String,
      model: m['modelo'] as String,
      color: m['cor'] as String,
      year: m['ano'] as int,
      seats: m['lugares'] as int,
      mileage: m['quilometragem'] as int,
      type: VehicleType.values.byName(m['tipo'] as String),
      status: VehicleStatus.values.byName(m['status'] as String),
      licensingExpiry: day('vencimento_licenciamento'),
      insuranceExpiry: day('vencimento_seguro'),
    );
  }
}
