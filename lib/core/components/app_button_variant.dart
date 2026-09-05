import 'package:flutter/material.dart';

import '../theme/app_colors.dart' show AppColors;

enum AppButtonVariant { confirm, cancel, login, settings, logout }

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
      case AppButtonVariant.settings:
        return AppColors.surface;
      case AppButtonVariant.logout:
        return AppColors.surface;
    }
  }

  BorderSide get _borderSide {
    switch (variant) {
      case AppButtonVariant.logout:
        return const BorderSide(color: Colors.red, width: 1.5);
      default:
        return BorderSide.none;
    }
  }

  TextStyle get _labelStyle {
    switch (variant) {
      case AppButtonVariant.confirm:
        return const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        );
      case AppButtonVariant.cancel:
        return const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        );
      case AppButtonVariant.login:
        return const TextStyle(color: Colors.white);
      case AppButtonVariant.settings:
        return const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        );
      case AppButtonVariant.logout:
        return const TextStyle(
          color: Colors.red,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        );
    }
  }

  double get _defaultWidth => variant == AppButtonVariant.login ? 291.58 : 320;
  double get _defaultHeight => variant == AppButtonVariant.login ? 41 : 50;

  @override
  Widget build(BuildContext context) {
    final bool hasTrailingIcon =
        variant == AppButtonVariant.settings ||
        variant == AppButtonVariant.logout;

    return SizedBox(
      width: width ?? _defaultWidth,
      height: height ?? _defaultHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor,
          padding: hasTrailingIcon
              ? const EdgeInsets.symmetric(horizontal: 20)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: _borderSide,
          ),
          elevation: variant == AppButtonVariant.logout ? 0 : 4,
          shadowColor: AppColors.shadow.withValues(alpha: 0.25),
        ),
        child: variant == AppButtonVariant.settings
            ? Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: _labelStyle),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppColors.iconMuted,
                  ),
                ],
              )
            : variant == AppButtonVariant.logout
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: _labelStyle),
                  const SizedBox(width: 16),
                  const Icon(Icons.logout, size: 16, color: Colors.red),
                ],
              )
            : Text(label, style: _labelStyle),
      ),
    );
  }
}
