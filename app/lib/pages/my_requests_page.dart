import 'package:flutter/material.dart';
import 'package:project/core/components/request_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/pages/new_request_page.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  /// Diálogo do check-out e do check-in: quilometragem + observação.
  Future<({int mileage, String? notes})?> _askMileage(
    BuildContext context, {
    required String title,
    required String description,
    int? minimum,
    String? minimumMessage,
  }) {
    final mileageController = TextEditingController();
    final notesController = TextEditingController();
    String? errorText;

    return showDialog<({int mileage, String? notes})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
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
                if (minimum != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Mínimo aceito: $minimum km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: mileageController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Quilometragem',
                    hintText: minimum != null ? '$minimum' : 'Ex.: 42500',
                    errorText: errorText,
                    errorMaxLines: 2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Observações (opcional)',
                    hintText: 'Ex.: nível de combustível, avarias...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(mileageController.text.trim());
                if (value == null) {
                  setDialogState(() => errorText = 'Informe um número válido.');
                  return;
                }
                if (minimum != null && value < minimum) {
                  setDialogState(
                    () => errorText =
                        minimumMessage ??
                        'O valor deve ser maior ou igual a $minimum km.',
                  );
                  return;
                }
                final notes = notesController.text.trim();
                Navigator.of(dialogContext)
                    .pop((mileage: value, notes: notes.isEmpty ? null : notes));
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
    final minimum = RequestController.instance.minimumCheckOutMileage(request);

    final result = await _askMileage(
      context,
      title: 'Retirada do veículo',
      description: vehicle == null
          ? 'Informe a quilometragem atual do painel.'
          : 'Informe a quilometragem atual do painel do '
                '${vehicle.model} (${vehicle.plate}).',
      minimum: minimum,
      minimumMessage:
          'A km de saída não pode ser menor que a '
          'quilometragem atual do veículo ($minimum km).',
    );
    if (result == null) return;

    final ok = RequestController.instance.checkOut(
      request.id,
      result.mileage,
      notes: result.notes,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Check-out registrado. Boa viagem!'
              : 'Não foi possível registrar o check-out. Verifique a km.',
        ),
      ),
    );
  }

  Future<void> _checkIn(BuildContext context, RequestModel request) async {
    final minimum = request.departureMileage;

    final result = await _askMileage(
      context,
      title: 'Devolução do veículo',
      description:
          'Informe a quilometragem do painel no momento '
          'da devolução. A km do veículo será atualizada.',
      minimum: minimum,
      minimumMessage:
          'A km de retorno não pode ser menor que a '
          'km de saída ($minimum km).',
    );
    if (result == null) return;

    final ok = RequestController.instance.checkIn(
      request.id,
      result.mileage,
      notes: result.notes,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Devolução registrada. Solicitação finalizada.'
              : 'Não foi possível registrar a devolução. Verifique a km.',
        ),
      ),
    );
  }

  void _edit(BuildContext context, RequestModel request) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NewRequestPage(request: request)));
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
        child: AnimatedBuilder(
          animation: RequestController.instance,
          builder: (context, _) {
            // Apenas as solicitações do usuário logado.
            final userId = UserController.instance.currentUser.id;
            final requests = RequestController.instance.requestsOf(userId);

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
                  onEdit: request.canEdit
                      ? () => _edit(context, request)
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
