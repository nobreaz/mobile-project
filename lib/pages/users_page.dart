import 'package:flutter/material.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/user_detail_page.dart';

/// Tela "Gestão de Usuários" — visão do aprovador sobre os colaboradores.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestão de Usuários',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          UserController.instance,
          RequestController.instance,
        ]),
        builder: (context, _) {
          final q = _query.trim().toLowerCase();
          final users = UserController.instance.users
              .where(
                (u) =>
                    q.isEmpty ||
                    u.name.toLowerCase().contains(q) ||
                    u.role.toLowerCase().contains(q) ||
                    u.department.toLowerCase().contains(q),
              )
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: TextField(
                  onChanged: (text) => setState(() => _query = text),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, cargo ou setor',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum usuário encontrado.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _userCard(context, users[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _userCard(BuildContext context, UserModel user) {
    final count = RequestController.instance.requestsOf(user.id).length;
    final cnh = user.cnhStatus;

    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserDetailPage(userId: user.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${user.role} · ${user.department}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip('CNH: ${cnh.label}', cnh.color),
                        _chip(
                          count == 1 ? '1 solicitação' : '$count solicitações',
                          AppColors.primary,
                        ),
                        if (user.profile == UserProfile.aprovador)
                          _chip('Aprovador', AppColors.primaryDark),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
