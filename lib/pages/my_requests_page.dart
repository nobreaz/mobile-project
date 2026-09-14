import 'package:flutter/material.dart';
import 'package:project/core/components/request_card.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/theme/app_colors.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

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
        // criada ou cancelada, a lista se atualiza sozinha.
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
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final request = requests[index];
                return RequestCard(
                  request: request,
                  onCancel: request.status == RequestStatus.pendente
                      ? () => RequestController.instance
                          .cancelRequest(request.id)
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
