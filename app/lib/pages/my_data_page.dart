import 'package:flutter/material.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/services/api_client.dart';
import 'package:project/core/theme/app_colors.dart';

/// Tela "Meus dados" — informações do usuário logado (seção 5.2).
/// Quase toda de leitura: só o telefone pode ser editado.
class MyDataPage extends StatelessWidget {
  const MyDataPage({super.key});

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  Future<void> _editPhone(BuildContext context, UserModel user) async {
    final controller = TextEditingController(text: user.phone ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Telefone / ramal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex.: (22) 99999-0000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    String message;
    try {
      await UserController.instance.updatePhone(result);
      message = 'Telefone atualizado.';
    } on ApiError catch (e) {
      message = e.message;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserController.instance,
      builder: (context, _) {
        final user = UserController.instance.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Meus dados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          backgroundColor: AppColors.background,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _header(user),
              const SizedBox(height: 24),
              _section('Dados pessoais', [
                _row(Icons.badge_outlined, 'Nome completo', user.name),
                _row(Icons.mail_outline, 'E-mail', user.email),
                _row(
                  Icons.phone_outlined,
                  'Telefone / ramal',
                  user.phone ?? 'Não informado',
                  trailing: IconButton(
                    onPressed: () => _editPhone(context, user),
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Editar telefone',
                  ),
                ),
                _row(Icons.work_outline, 'Cargo', user.role),
                _row(Icons.apartment_outlined, 'Setor', user.department),
              ]),
              const SizedBox(height: 24),
              _cnhSection(user),
              const SizedBox(height: 24),
              _section('Acesso', [
                _row(
                  Icons.verified_user_outlined,
                  'Perfil no sistema',
                  user.profile.label,
                ),
              ]),
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Para alterar nome, cargo, CNH ou perfil, procure o '
                      'setor Administrativo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Blocos da tela
  // ---------------------------------------------------------------------

  Widget _header(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primary,
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${user.role} · ${user.department}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.profile.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cnhSection(UserModel user) {
    final status = user.cnhStatus;
    final days = user.daysToCnhExpiry;

    final String message;
    switch (status) {
      case CnhStatus.valida:
        message = 'Válida até ${_fmtDate(user.cnhExpiry)}';
      case CnhStatus.vencendo:
        message = days == 0
            ? 'Vence hoje. Renove para continuar solicitando veículos.'
            : 'Vence em $days dia(s). Renove para continuar '
                  'solicitando veículos.';
      case CnhStatus.vencida:
        message =
            'Vencida desde ${_fmtDate(user.cnhExpiry)}. Você não pode '
            'solicitar veículos até regularizar.';
      case CnhStatus.naoInformada:
        message = 'CNH não cadastrada. Procure o setor Administrativo.';
    }

    return _section('Habilitação (CNH)', [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(status.icon, color: status.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: status.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _row(Icons.credit_card, 'Número', user.cnhNumber ?? '—'),
      _row(Icons.category_outlined, 'Categoria', user.cnhCategory ?? '—'),
      _row(Icons.event_outlined, 'Validade', _fmtDate(user.cnhExpiry)),
    ]);
  }

  // ---------------------------------------------------------------------
  // Componentes reutilizados
  // ---------------------------------------------------------------------

  ShapeDecoration _cardDecoration() {
    return ShapeDecoration(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadows: const [
        BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 4)),
      ],
    );
  }

  /// Título da seção + card branco com as linhas separadas por divisórias.
  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 52),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 4, 12),
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
