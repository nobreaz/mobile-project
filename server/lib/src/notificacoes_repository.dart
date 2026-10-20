import 'package:frota_core/frota_core.dart';
import 'package:postgres/postgres.dart';

/// Acesso à tabela `notificacoes` (RF 3.3.7). As notificações são criadas
/// pelo `FrotaService`, na mesma transação da mudança que as gerou.
class NotificacoesRepository {
  NotificacoesRepository(this._db);

  final Session _db;

  static const _columns = '''
    id, usuario_id, solicitacao_id, tipo::text AS tipo,
    destino, mensagem, lida, criada_em''';

  Future<void> insert({
    required int userId,
    required int requestId,
    required NotificationType type,
    required String destination,
    required String message,
  }) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO notificacoes (
          usuario_id, solicitacao_id, tipo, destino, mensagem
        ) VALUES (
          @user, @request, @type::tipo_notificacao, @destination, @message
        )'''),
      parameters: {
        'user': userId,
        'request': requestId,
        'type': type.name,
        'destination': destination,
        'message': message,
      },
    );
  }

  /// Notificações do usuário, mais recentes primeiro (no máximo [limit]).
  Future<List<AppNotification>> listFor(int userId, {int limit = 100}) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT $_columns FROM notificacoes WHERE usuario_id = @user '
        'ORDER BY criada_em DESC, id DESC LIMIT @limit',
      ),
      parameters: {'user': userId, 'limit': limit},
    );
    return result.map(_fromRow).toList();
  }

  /// Marca todas as notificações do usuário como lidas.
  Future<void> markAllRead(int userId) async {
    await _db.execute(
      Sql.named(
        'UPDATE notificacoes SET lida = true '
        'WHERE usuario_id = @user AND NOT lida',
      ),
      parameters: {'user': userId},
    );
  }

  static AppNotification _fromRow(ResultRow row) {
    final m = row.toColumnMap();
    return AppNotification(
      id: m['id'] as int,
      userId: m['usuario_id'] as int,
      requestId: m['solicitacao_id'] as int,
      type: NotificationType.values.byName(m['tipo'] as String),
      destination: m['destino'] as String,
      message: m['mensagem'] as String,
      createdAt: (m['criada_em'] as DateTime).toLocal(),
      read: m['lida'] as bool,
    );
  }
}
