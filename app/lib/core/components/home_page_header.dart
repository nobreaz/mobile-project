import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class HomePageHeader extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onLogout;
  final String? avatarUrl;

  const HomePageHeader({
    super.key,
    required this.name,
    required this.role,
    required this.onLogout,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.background,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 32)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.userName),
                Text(role, style: AppTextStyles.userRole),
              ],
            ),
          ],
        ),
        ElevatedButton(
          onPressed: onLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            iconColor: AppColors.background,
            shadowColor: Colors.transparent,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(14),
          ),
          child: const Icon(Icons.exit_to_app),
        ),
      ],
    );
  }
}
