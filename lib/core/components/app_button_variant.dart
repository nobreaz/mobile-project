import 'package:flutter/material.dart';

import '../theme/app_colors.dart' show AppColors;

enum AppButtonVariant { confirm, cancel, login }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final AppButtonVariant variant;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.confirm,
    this.width,
    this.height,
  });

  Color get _backgroundColor {
    switch (variant) {
      case AppButtonVariant.confirm:
        return AppColors.primary;
      case AppButtonVariant.cancel:
        return AppColors.iconMuted;
      case AppButtonVariant.login:
        return AppColors.primaryDark.withValues(alpha: 0.70);
    }
  }

  TextStyle get _labelStyle {
    switch (variant) {
      case AppButtonVariant.confirm:
        return const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700);
      case AppButtonVariant.cancel:
        return const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700);
      case AppButtonVariant.login:
        return const TextStyle(color: Colors.white);
    }
  }

  double get _defaultWidth => variant == AppButtonVariant.login ? 291.58 : 320;
  double get _defaultHeight => variant == AppButtonVariant.login ? 41 : 50;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? _defaultWidth,
      height: height ?? _defaultHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          shadowColor: AppColors.shadow.withValues(alpha: 0.25),
        ),
        child: Text(label, style: _labelStyle),
      ),
    );
  }
}