import 'package:flutter/material.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Card que exibe um veículo na tela "Gestão de Veículos",
/// com as ações de editar e remover.
class VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  vehicle.type.icon,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.model,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      vehicle.plate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: vehicle.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vehicle.status.label,
                  style: TextStyle(
                    color: vehicle.status.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _info(Icons.event_seat, '${vehicle.seats} lugares'),
              _info(Icons.speed, '${vehicle.mileage} km'),
              _info(Icons.calendar_today, '${vehicle.year}'),
              _info(Icons.palette_outlined, vehicle.color),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit,
                    size: 16, color: AppColors.primary),
                label: const Text(
                  'Editar',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.rejected),
                label: const Text(
                  'Remover',
                  style: TextStyle(
                    color: AppColors.rejected,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.iconMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
