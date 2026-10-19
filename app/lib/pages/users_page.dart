import 'package:flutter/material.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/user_detail_page.dart';
import 'package:project/pages/user_form_page.dart';

/// Tela "Gestão de Usuários" — visão do Administrador sobre os colaboradores.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    UserController.instance.loadUsers();
  }

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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const UserFormPage())),
        icon: const Icon(Icons.person_add_alt),
        label: const Text(
          'Cadastrar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          UserController.instance,
          RequestController.instance,
        ]),
        builder: (context, _) {
          final controller = UserController.instance;
          if (controller.loadingUsers && controller.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.usersError != null && controller.users.isEmpty) {
            return _errorState(controller.usersError!);
          }

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
                    : RefreshIndicator(
                        onRefresh: controller.loadUsers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _userCard(context, users[index]),
                        ),
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
                        if (user.profile != UserProfile.padrao)
                          _chip(user.profile.label, AppColors.primaryDark),
                        if (!user.active) _chip('Inativo', AppColors.rejected),
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

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.iconMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: UserController.instance.loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
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
