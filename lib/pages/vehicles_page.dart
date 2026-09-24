import 'package:flutter/material.dart';
import 'package:project/core/components/vehicle_card.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/vehicle_form_page.dart';

/// Tela "Gestão de Veículos" — lista a frota e dá acesso ao CRUD.
/// (Requisitos 3.2.1 a 3.2.5 do documento.)
class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  void _openForm(BuildContext context, {VehicleModel? vehicle}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleFormPage(vehicle: vehicle),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VehicleModel vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover veículo'),
        content: Text(
          'Tem certeza que deseja remover o veículo '
          '${vehicle.model} (${vehicle.plate})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remover',
              style: TextStyle(color: AppColors.rejected),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      VehicleController.instance.removeVehicle(vehicle.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestão de Veículos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text(
          'Cadastrar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: VehicleController.instance,
        builder: (context, _) {
          final vehicles = VehicleController.instance.vehicles;

          if (vehicles.isEmpty) {
            return _emptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return VehicleCard(
                vehicle: vehicle,
                onEdit: () => _openForm(context, vehicle: vehicle),
                onDelete: () => _confirmDelete(context, vehicle),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 72, color: AppColors.iconMuted),
          SizedBox(height: 12),
          Text(
            'Nenhum veículo cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Toque em "Cadastrar" para adicionar o primeiro.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
