import 'package:flutter/material.dart';

import '../theme/app_colors.dart' show AppColors;

class AuthTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final bool obscureable;
  final TextInputType? keyboardType;
  final double widthFactor;

  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.obscureable = false,
    this.keyboardType,
    this.widthFactor = 0.8,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * widget.widthFactor,
      margin: const EdgeInsets.only(top: 20),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadows: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: widget.onChanged,
        obscureText: widget.obscureable ? _obscure : false,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, color: AppColors.iconMuted),
          suffixIcon: widget.obscureable
              ? IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.iconMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
      ),
    );
  }
}
