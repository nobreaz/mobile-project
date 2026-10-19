import 'package:flutter/material.dart';
import 'package:project/core/components/vehicle_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/vehicle_form_page.dart';

/// Tela "Gestão de Veículos" — lista a frota e dá acesso ao CRUD.
/// (Requisitos 3.2.1 a 3.2.5 do documento.)
class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  void _openForm(BuildContext context, {VehicleModel? vehicle}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleFormPage(vehicle: vehicle)),
    );
  }

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Requisito 3.2.4: o veículo é desativado, nunca apagado,
  /// para manter o histórico das solicitações que o usaram.
  Future<void> _toggleActive(BuildContext context, VehicleModel vehicle) async {
    if (vehicle.status == VehicleStatus.inativo) {
      VehicleController.instance.reactivateVehicle(vehicle.id);
      _showMessage(context, 'Veículo reativado e disponível na frota.');
      return;
    }

    final bookings = RequestController.instance.activeBookingsOf(vehicle.id);

    // Carro em viagem: precisa do check-in antes de sair da frota.
    if (bookings.any((r) => r.status == RequestStatus.emUso)) {
      _showMessage(
        context,
        'O veículo está em uso. Registre a devolução (check-in) '
        'antes de desativá-lo.',
      );
      return;
    }

    final approved = bookings
        .where((r) => r.status == RequestStatus.aprovada)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desativar veículo'),
        content: Text(
          'O veículo ${vehicle.model} (${vehicle.plate}) deixará de aparecer '
          'para novos agendamentos. O histórico de uso é mantido e você pode '
          'reativá-lo depois.'
          '${approved.isEmpty ? '' : '\n\n${approved.length} reserva(s) '
                    'aprovada(s) voltarão para "Pendente" e precisarão '
                    'de outro veículo.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Desativar',
              style: TextStyle(color: AppColors.rejected),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    RequestController.instance.releaseBookings(approved.map((r) => r.id));
    VehicleController.instance.deactivateVehicle(vehicle.id);
    _showMessage(context, 'Veículo desativado.');
  }

  @override
  Widget build(BuildContext context) {
    // Só o Administrador altera a frota; o Aprovador apenas consulta.
    final canEdit =
        UserController.instance.currentUser.profile.canManageRegistry;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          canEdit ? 'Gestão de Veículos' : 'Frota',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'Cadastrar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: AnimatedBuilder(
        animation: VehicleController.instance,
        builder: (context, _) {
          final vehicles = VehicleController.instance.vehicles;

          if (vehicles.isEmpty) {
            return _emptyState(canEdit);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return VehicleCard(
                vehicle: vehicle,
                onEdit: canEdit
                    ? () => _openForm(context, vehicle: vehicle)
                    : null,
                onToggleActive: canEdit
                    ? () => _toggleActive(context, vehicle)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(bool canEdit) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_outlined,
            size: 72,
            color: AppColors.iconMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhum veículo cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canEdit
                ? 'Toque em "Cadastrar" para adicionar o primeiro.'
                : 'O cadastro de veículos é feito pelo Administrador.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
