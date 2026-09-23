import 'package:flutter/material.dart';
import 'package:project/core/components/pending_request_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';

/// Tela do aprovador: lista as solicitações pendentes e permite
/// aprovar (alocando um veículo) ou recusar (com justificativa).
/// Requisitos 3.3.3, 3.3.4 e regras 4.1 / 4.7 do documento.
class PendingRequestsPage extends StatelessWidget {
  const PendingRequestsPage({super.key});

  /// Fluxo de aprovação: o aprovador escolhe o veículo a alocar.
  /// A lista já vem filtrada e ordenada pela regra RN 4.1.
  Future<void> _approve(BuildContext context, RequestModel request) async {
    final eligible = RequestController.instance.eligibleVehicles(request);

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum veículo disponível atende aos critérios desta solicitação.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<VehicleModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _VehiclePicker(
        vehicles: eligible,
        passengers: request.passengers,
      ),
    );

    if (selected == null) return;

    RequestController.instance.approveRequest(request.id, selected.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solicitação #${request.id} aprovada — veículo ${selected.plate}.',
        ),
      ),
    );
  }

  /// Fluxo de recusa: a justificativa é obrigatória (regra 4.7).
  Future<void> _reject(BuildContext context, RequestModel request) async {
    final controller = TextEditingController();

    final justification = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recusar solicitação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o motivo da recusa. A justificativa é obrigatória.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex.: nenhum veículo disponível na data.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return; // bloqueia recusa sem justificativa
              Navigator.of(dialogContext).pop(text);
            },
            child: const Text(
              'Confirmar recusa',
              style: TextStyle(color: AppColors.rejected),
            ),
          ),
        ],
      ),
    );

    if (justification == null) return;

    RequestController.instance.rejectRequest(request.id, justification);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Solicitação #${request.id} recusada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Solicitações Pendentes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: RequestController.instance,
        builder: (context, _) {
          final pending = RequestController.instance.pendingRequests;

          if (pending.isEmpty) {
            return _emptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: pending.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final request = pending[index];
              return PendingRequestCard(
                request: request,
                onApprove: () => _approve(context, request),
                onReject: () => _reject(context, request),
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
          Icon(Icons.task_alt, size: 72, color: AppColors.iconMuted),
          SizedBox(height: 12),
          Text(
            'Nenhuma solicitação pendente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tudo em dia por aqui.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Lista de veículos elegíveis exibida ao aprovar.
/// Já chega filtrada (disponíveis + lugares suficientes) e
/// ordenada por menor quilometragem — regra RN 4.1.
class _VehiclePicker extends StatelessWidget {
  final List<VehicleModel> vehicles;
  final int passengers;

  const _VehiclePicker({required this.vehicles, required this.passengers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Alocar veículo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Disponíveis com pelo menos $passengers lugar(es), '
              'ordenados por menor quilometragem.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];
                final isSuggested = index == 0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.background,
                    child: Icon(v.type.icon, color: AppColors.primary),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          v.model,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isSuggested) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.approved.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Sugerido',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.approved,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${v.plate} · ${v.seats} lugares · ${v.mileage} km',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.iconMuted,
                  ),
                  onTap: () => Navigator.of(context).pop(v),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
