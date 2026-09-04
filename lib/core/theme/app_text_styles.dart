import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Instrument Sans';

  static const heading = TextStyle(
    color: AppColors.primary,
    fontSize: 36,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
  );

  static const subtitle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 15,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
  );

  static const link = TextStyle(
    color: AppColors.primary,
    fontSize: 14,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );

  static const userName = TextStyle(
    color: AppColors.background,
    fontSize: 16,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
  );

  static const userRole = TextStyle(
    color: AppColors.background,
    fontSize: 14,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
  );

  static const actionLabel = TextStyle(
    color: AppColors.primary,
    fontSize: 13,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
  );

  static const welcomeMessage = TextStyle(
    color: AppColors.background,
    fontSize: 20,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
  );
}
