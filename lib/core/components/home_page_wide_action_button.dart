// dashboard_wide_action_button.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class HomePageWideActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;

  const HomePageWideActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.primary),
        label: Text(label, style: AppTextStyles.actionLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          elevation: 2,
          shadowColor: AppColors.shadow,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
