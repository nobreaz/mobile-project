import 'package:flutter/material.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Card que exibe uma solicitação na tela "Minhas Solicitações".
class RequestCard extends StatelessWidget {
  final RequestModel request;
  final VoidCallback? onCancel;

  const RequestCard({super.key, required this.request, this.onCancel});

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDateTime(DateTime? d) => d == null
      ? '—'
      : '${_pad(d.day)}/${_pad(d.month)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}';

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadows: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: status + número da solicitação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: request.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  request.status.label,
                  style: TextStyle(
                    color: request.status.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                'Solicitação #${request.id}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Viagem a ${request.destination}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            request.reason,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.people_outline, '${request.passengers} passageiro(s)'),
          const SizedBox(height: 4),
          _infoRow(Icons.event, 'Saída: ${_fmtDateTime(request.departure)}'),
          const SizedBox(height: 4),
          _infoRow(
              Icons.calendar_today, 'Retorno: ${_fmtDate(request.returnDate)}'),
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close,
                    size: 16, color: AppColors.rejected),
                label: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.rejected,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.iconMuted),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
