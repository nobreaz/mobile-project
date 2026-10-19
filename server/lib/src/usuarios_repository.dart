import 'package:frota_core/frota_core.dart';
import 'package:postgres/postgres.dart';

/// Acesso à tabela `usuarios`. Só SQL e conversão linha → [UserModel];
/// regras de negócio ficam nas rotas e no frota_core.
class UsuariosRepository {
  UsuariosRepository(this._db);

  final Session _db;

  // Enums viram texto na leitura (o pacote não decodifica tipos próprios)
  // e voltam para o tipo do banco na escrita (`::perfil_usuario`).
  static const _columns = '''
    id, nome, email, telefone, cargo, setor,
    cnh_numero, cnh_categoria, cnh_validade, perfil::text AS perfil, ativo''';

  /// Colunas que podem ser alteradas por [update], com o tipo SQL de cada uma.
  static const editableColumns = {
    'nome': 'text',
    'telefone': 'text',
    'cargo': 'text',
    'setor': 'text',
    'cnh_numero': 'text',
    'cnh_categoria': 'text',
    'cnh_validade': 'date',
    'perfil': 'perfil_usuario',
    'ativo': 'boolean',
  };

  Future<UserModel?> findByAuthId(String authId) => _one(
    'SELECT $_columns FROM usuarios WHERE auth_id = @authId::uuid',
    {'authId': authId},
  );

  Future<UserModel?> findById(int id) =>
      _one('SELECT $_columns FROM usuarios WHERE id = @id', {'id': id});

  Future<bool> emailExists(String email) async {
    final result = await _db.execute(
      Sql.named('SELECT 1 FROM usuarios WHERE email = @email'),
      parameters: {'email': email},
    );
    return result.isNotEmpty;
  }

  /// Todos os usuários, ativos primeiro e em ordem alfabética.
  Future<List<UserModel>> list() async {
    final result = await _db.execute(
      'SELECT $_columns FROM usuarios ORDER BY ativo DESC, nome',
    );
    return result.map(_fromRow).toList();
  }

  /// Id do login no Supabase Auth (para bloquear/liberar o acesso).
  Future<String?> authIdOf(int id) async {
    final result = await _db.execute(
      Sql.named('SELECT auth_id::text FROM usuarios WHERE id = @id'),
      parameters: {'id': id},
    );
    return result.isEmpty ? null : result.first.first as String?;
  }

  Future<UserModel> insert(UserModel user, {required String authId}) async {
    final created = await _one(
      '''
      INSERT INTO usuarios (
        auth_id, nome, email, telefone, cargo, setor,
        cnh_numero, cnh_categoria, cnh_validade, perfil
      ) VALUES (
        @authId::uuid, @nome, @email, @telefone, @cargo, @setor,
        @cnhNumero, @cnhCategoria, @cnhValidade::date,
        @perfil::perfil_usuario
      )
      RETURNING $_columns''',
      {
        'authId': authId,
        'nome': user.name,
        'email': user.email,
        'telefone': user.phone,
        'cargo': user.role,
        'setor': user.department,
        'cnhNumero': user.cnhNumber,
        'cnhCategoria': user.cnhCategory,
        'cnhValidade': user.cnhExpiry == null
            ? null
            : formatDate(user.cnhExpiry!),
        'perfil': user.profile.name,
      },
    );
    return created!;
  }

  /// Altera só as colunas recebidas em [changes] (nomes de [editableColumns]).
  /// Devolve o usuário atualizado ou `null` se o id não existir.
  Future<UserModel?> update(int id, Map<String, Object?> changes) {
    if (changes.isEmpty) return findById(id);

    final sets = <String>[];
    for (final column in changes.keys) {
      final type = editableColumns[column];
      if (type == null) throw ArgumentError('Coluna não editável: $column');
      sets.add('$column = @$column::$type');
    }

    return _one(
      'UPDATE usuarios SET ${sets.join(', ')} WHERE id = @id '
      'RETURNING $_columns',
      {
        ...changes.map(
          (k, v) => MapEntry(k, v is DateTime ? formatDate(v) : v),
        ),
        'id': id,
      },
    );
  }

  Future<UserModel?> _one(String sql, Map<String, Object?> parameters) async {
    final result = await _db.execute(Sql.named(sql), parameters: parameters);
    return result.isEmpty ? null : _fromRow(result.first);
  }

  static UserModel _fromRow(ResultRow row) {
    final m = row.toColumnMap();
    final cnh = m['cnh_validade'] as DateTime?;
    return UserModel(
      id: m['id'] as int,
      name: m['nome'] as String,
      email: m['email'] as String,
      phone: m['telefone'] as String?,
      role: m['cargo'] as String,
      department: m['setor'] as String,
      cnhNumber: m['cnh_numero'] as String?,
      cnhCategory: m['cnh_categoria'] as String?,
      // `date` chega como meia-noite UTC; guardamos só o dia.
      cnhExpiry: cnh == null ? null : DateTime(cnh.year, cnh.month, cnh.day),
      profile: UserProfile.values.byName(m['perfil'] as String),
      active: m['ativo'] as bool,
    );
  }
}
