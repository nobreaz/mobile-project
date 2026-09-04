import 'package:flutter/material.dart';

import '../theme/app_colors.dart' show AppColors;

class AuthBackground extends StatelessWidget {
  final double topFlex; // proporção 0.0–1.0 ocupada pela cor de cima
  final List<Widget> Function(BuildContext context, double dividerY) children;

  const AuthBackground({
    super.key,
    this.topFlex = 0.35,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dividerY = constraints.maxHeight * topFlex;
        final int flexTop = (topFlex * 100).round();

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: flexTop,
                  child: Container(
                    color: AppColors.primary,
                    width: double.infinity,
                  ),
                ),
                Expanded(
                  flex: 100 - flexTop,
                  child: Container(
                    color: AppColors.background,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
            ...children(context, dividerY),
          ],
        );
      },
    );
  }
}
