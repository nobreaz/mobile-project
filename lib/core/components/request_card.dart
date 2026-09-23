import 'package:flutter/material.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Card que exibe uma solicitação na tela "Minhas Solicitações".
class RequestCard extends StatelessWidget {
  final RequestModel request;
  final VoidCallback? onCancel;
  final VoidCallback? onCheckOut;
  final VoidCallback? onCheckIn;

  const RequestCard({
    super.key,
    required this.request,
    this.onCancel,
    this.onCheckOut,
    this.onCheckIn,
  });

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDateTime(DateTime? d) => d == null
      ? '—'
      : '${_pad(d.day)}/${_pad(d.month)}/${d.year} ${_pad(d.hour)}:${_pad(d.minute)}';

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final vehicle = RequestController.instance.vehicleOf(request);
    final isLate = request.isCheckOutLate || request.isReturnLate;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
            Icons.calendar_today,
            'Retorno: ${_fmtDate(request.returnDate)}',
          ),

          // Alerta de atraso (retirada ou devolução fora do prazo)
          if (isLate) ...[
            const SizedBox(height: 10),
            _banner(
              color: AppColors.canceled,
              icon: Icons.schedule,
              text: request.isCheckOutLate
                  ? 'A data de saída já passou e o veículo não foi retirado.'
                  : 'A data de retorno já passou e o veículo não foi devolvido.',
            ),
          ],

          // Veículo alocado (aparece a partir da aprovação)
          if (vehicle != null) ...[
            const SizedBox(height: 10),
            _banner(
              color: AppColors.approved,
              icon: vehicle.type.icon,
              text: 'Veículo alocado: ${vehicle.model} · ${vehicle.plate}',
            ),
          ],

          // Quilometragem registrada no uso
          if (request.departureMileage != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.speed,
              'Km de saída: ${request.departureMileage}'
              '${request.returnMileage != null ? ' · Km de retorno: ${request.returnMileage}' : ''}',
            ),
          ],
          if (request.distanceTravelled != null) ...[
            const SizedBox(height: 4),
            _infoRow(
              Icons.route,
              'Distância percorrida: ${request.distanceTravelled} km',
            ),
          ],

          // Justificativa da recusa (regra 4.7)
          if (request.status == RequestStatus.recusada &&
              request.rejectionReason != null) ...[
            const SizedBox(height: 10),
            _banner(
              color: AppColors.rejected,
              icon: Icons.info_outline,
              text: 'Motivo da recusa: ${request.rejectionReason}',
            ),
          ],

          // Ações disponíveis conforme o status
          if (onCheckOut != null) ...[
            const SizedBox(height: 12),
            _actionButton(
              label: 'Retirar veículo (check-out)',
              icon: Icons.login,
              color: AppColors.primary,
              onPressed: onCheckOut!,
            ),
          ],
          if (onCheckIn != null) ...[
            const SizedBox(height: 12),
            _actionButton(
              label: 'Devolver veículo (check-in)',
              icon: Icons.logout,
              color: AppColors.approved,
              onPressed: onCheckIn!,
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.rejected,
                ),
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

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.iconMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
