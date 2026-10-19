import 'package:flutter/material.dart';
import 'package:project/core/components/request_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/services/api_client.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/user_form_page.dart';

/// Detalhes de um colaborador: resumo, dados e histórico de solicitações.
class UserDetailPage extends StatelessWidget {
  final int userId;

  const UserDetailPage({super.key, required this.userId});

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        UserController.instance,
        RequestController.instance,
        VehicleController.instance,
      ]),
      builder: (context, _) {
        final user = UserController.instance.userById(userId);

        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: Text('Usuário não encontrado.')),
          );
        }

        final requests = RequestController.instance.requestsOf(user.id);
        final finished = requests
            .where((r) => r.status == RequestStatus.finalizada)
            .toList();
        final km = finished.fold<int>(
          0,
          (sum, r) => sum + (r.distanceTravelled ?? 0),
        );
        final delays = requests
            .where(
              (r) => r.wasReturnedLate || r.isReturnLate || r.isCheckOutLate,
            )
            .length;

        final isSelf = user.id == UserController.instance.currentUser.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Detalhes do usuário',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UserFormPage(user: user)),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.background,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _header(user),
              const SizedBox(height: 20),
              _stats(
                total: requests.length,
                finished: finished.length,
                km: km,
                delays: delays,
              ),
              const SizedBox(height: 20),
              _info(user),
              if (!isSelf) ...[
                const SizedBox(height: 12),
                _accessButton(context, user),
              ],
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Histórico de solicitações',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhuma solicitação registrada.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                for (final r in requests) ...[
                  RequestCard(request: r), // somente leitura
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  /// Desativar ou reativar o acesso. O usuário nunca é apagado:
  /// o histórico de solicitações continua disponível.
  Widget _accessButton(BuildContext context, UserModel user) {
    final deactivate = user.active;
    final color = deactivate ? AppColors.rejected : AppColors.approved;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(deactivate ? Icons.block : Icons.restart_alt),
      label: Text(
        deactivate ? 'Desativar acesso' : 'Reativar acesso',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onPressed: () => _toggleAccess(context, user),
    );
  }

  Future<void> _toggleAccess(BuildContext context, UserModel user) async {
    final deactivate = user.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deactivate ? 'Desativar acesso' : 'Reativar acesso'),
        content: Text(
          deactivate
              ? '${user.name} não conseguirá mais entrar no aplicativo. '
                    'O histórico de solicitações é mantido e você pode '
                    'reativar depois.'
              : '${user.name} voltará a ter acesso ao aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              deactivate ? 'Desativar' : 'Reativar',
              style: TextStyle(
                color: deactivate ? AppColors.rejected : AppColors.approved,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    String message;
    try {
      await UserController.instance.updateUser(user.id, {
        'active': !deactivate,
      });
      message = deactivate ? 'Acesso desativado.' : 'Acesso reativado.';
    } on ApiError catch (e) {
      message = e.message;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  ShapeDecoration _cardDecoration() {
    return ShapeDecoration(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadows: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 4)),
      ],
    );
  }

  Widget _header(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.role} · ${user.department}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!user.active) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'ACESSO DESATIVADO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.rejected,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats({
    required int total,
    required int finished,
    required int km,
    required int delays,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: [
        _stat(Icons.list_alt, 'Solicitações', '$total'),
        _stat(Icons.flag_outlined, 'Viagens finalizadas', '$finished'),
        _stat(Icons.route, 'Km rodados', '$km km'),
        _stat(
          Icons.schedule,
          'Atrasos',
          '$delays',
          color: delays > 0 ? AppColors.rejected : null,
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value, {Color? color}) {
    final c = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(UserModel user) {
    final cnh = user.cnhStatus;

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _row(Icons.mail_outline, 'E-mail', user.email),
          const Divider(height: 1, indent: 52),
          _row(
            Icons.phone_outlined,
            'Telefone / ramal',
            user.phone ?? 'Não informado',
          ),
          const Divider(height: 1, indent: 52),
          _row(
            Icons.credit_card,
            'CNH',
            '${user.cnhCategory ?? '—'} · validade ${_fmtDate(user.cnhExpiry)}',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cnh.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cnh.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cnh.color,
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 52),
          _row(
            Icons.verified_user_outlined,
            'Perfil no sistema',
            user.profile.label,
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.iconMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
