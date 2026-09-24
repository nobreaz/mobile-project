import 'package:flutter/material.dart';
import 'package:project/core/components/request_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/theme/app_colors.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  /// Diálogo único usado tanto no check-out quanto no check-in.
  /// Pede a quilometragem e valida o valor informado.
  Future<int?> _askMileage(
    BuildContext context, {
    required String title,
    required String description,
    int? minimum,
  }) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Quilometragem',
                  hintText: 'Ex.: 42500',
                  errorText: errorText,
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
                final value = int.tryParse(controller.text.trim());
                if (value == null) {
                  setDialogState(
                    () => errorText = 'Informe um número válido.',
                  );
                  return;
                }
                if (minimum != null && value < minimum) {
                  setDialogState(
                    () => errorText =
                        'Deve ser maior ou igual à km de saída ($minimum).',
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkOut(BuildContext context, RequestModel request) async {
    final vehicle = RequestController.instance.vehicleOf(request);

    final mileage = await _askMileage(
      context,
      title: 'Retirada do veículo',
      description: vehicle == null
          ? 'Informe a quilometragem atual do painel.'
          : 'Informe a quilometragem atual do painel do '
              '${vehicle.model} (${vehicle.plate}).',
    );
    if (mileage == null) return;

    RequestController.instance.checkOut(request.id, mileage);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-out registrado. Boa viagem!')),
    );
  }

  Future<void> _checkIn(BuildContext context, RequestModel request) async {
    final mileage = await _askMileage(
      context,
      title: 'Devolução do veículo',
      description: 'Informe a quilometragem do painel no momento '
          'da devolução. A km do veículo será atualizada.',
      minimum: request.departureMileage,
    );
    if (mileage == null) return;

    RequestController.instance.checkIn(request.id, mileage);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Devolução registrada. Solicitação finalizada.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minhas Solicitações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        // Ouve o RequestController: sempre que uma solicitação é
        // criada ou alterada, a lista se atualiza sozinha.
        child: AnimatedBuilder(
          animation: RequestController.instance,
          builder: (context, _) {
            final requests = RequestController.instance.requests;

            if (requests.isEmpty) {
              return _emptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final request = requests[index];

                return RequestCard(
                  request: request,
                  onCancel: request.status == RequestStatus.pendente
                      ? () =>
                          RequestController.instance.cancelRequest(request.id)
                      : null,
                  onCheckOut: request.status == RequestStatus.aprovada
                      ? () => _checkOut(context, request)
                      : null,
                  onCheckIn: request.status == RequestStatus.emUso
                      ? () => _checkIn(context, request)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: AppColors.iconMuted),
          SizedBox(height: 12),
          Text(
            'Nenhuma solicitação ainda',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Suas solicitações aparecerão aqui.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
