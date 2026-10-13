import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class HomePageActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Quando `true`, exibe a faixa "Em breve" e bloqueia a ação.
  final bool comingSoon;

  const HomePageActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.comingSoon = false,
  });

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label estará disponível em breve.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: comingSoon ? () => _showComingSoon(context) : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(12),
      ),
      child: Opacity(
        opacity: comingSoon ? 0.5 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.actionLabel,
            ),
          ],
        ),
      ),
    );

    if (!comingSoon) return button;

    // Faixa diagonal vermelha no canto superior direito.
    return Stack(
      fit: StackFit.expand,
      children: [
        button,
        IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: const Banner(
              message: 'EM BREVE',
              location: BannerLocation.topEnd,
              color: AppColors.rejected,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
