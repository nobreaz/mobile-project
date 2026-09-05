import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project/core/theme/app_text_styles.dart';

import '../theme/app_colors.dart' show AppColors;

enum InputFieldType { text, number, date, dateTime }

class InputTextField extends StatefulWidget {
  final String label;
  final String inputText;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final double widthFactor;
  final String? hint;
  final InputFieldType type;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime>? onDateSelected;

  const InputTextField({
    super.key,
    required this.inputText,
    required this.label,
    required this.onChanged,
    this.keyboardType,
    this.widthFactor = 0.8,
    this.hint,
    this.type = InputFieldType.text,
    this.firstDate,
    this.lastDate,
    this.onDateSelected,
  });

  @override
  State<InputTextField> createState() => _InputTextFieldState();
}

class _InputTextFieldState extends State<InputTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.inputText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _formatDate(DateTime date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  String _formatDateTime(DateTime date) =>
      '${_formatDate(date)} ${_pad(date.hour)}:${_pad(date.minute)}';

  Future<void> _handleTap() async {
    final now = DateTime.now();
    final effectiveFirstDate = widget.firstDate ?? now;
    // se firstDate for no futuro, o initialDate "pulará" pra lá também
    final initialDate = effectiveFirstDate.isAfter(now)
        ? effectiveFirstDate
        : now;

    if (widget.type == InputFieldType.date) {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: effectiveFirstDate,
        lastDate: widget.lastDate ?? DateTime(2100),
      );
      if (picked != null) _applyDate(picked);
    } else if (widget.type == InputFieldType.dateTime) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: effectiveFirstDate,
        lastDate: widget.lastDate ?? DateTime(2100),
      );
      if (pickedDate == null || !mounted) return;

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime == null) return;

      _applyDate(
        DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        ),
      );
    }
  }

  void _applyDate(DateTime date) {
    final formatted = widget.type == InputFieldType.dateTime
        ? _formatDateTime(date)
        : _formatDate(date);

    setState(() => _controller.text = formatted);
    widget.onChanged(formatted);
    widget.onDateSelected?.call(date);
  }

  @override
  Widget build(BuildContext context) {
    final isPickerField =
        widget.type == InputFieldType.date ||
        widget.type == InputFieldType.dateTime;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(widget.label, style: AppTextStyles.actionLabel),
        ),
        Container(
          width: MediaQuery.of(context).size.width * widget.widthFactor,
          margin: const EdgeInsets.only(top: 8),
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            shadows: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            readOnly: isPickerField,
            onTap: isPickerField ? _handleTap : null,
            onChanged: isPickerField ? null : widget.onChanged,
            keyboardType: widget.type == InputFieldType.number
                ? TextInputType.number
                : widget.keyboardType,
            inputFormatters: widget.type == InputFieldType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            decoration: InputDecoration(
              border: const OutlineInputBorder(borderSide: BorderSide.none),
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              suffixIcon: widget.type == InputFieldType.date
                  ? const Icon(Icons.calendar_today, color: AppColors.iconMuted)
                  : widget.type == InputFieldType.dateTime
                  ? const Icon(Icons.event, color: AppColors.iconMuted)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
