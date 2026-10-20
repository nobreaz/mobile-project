import 'package:flutter/material.dart';
import 'package:project/core/theme/app_colors.dart';

/// Recarrega dados da API toda vez que a tela abre (ex.: o aprovador
/// decidiu algo desde a última vez). Enquanto isso, a tela mostra o que
/// já estava carregado.
class RefreshOnOpen extends StatefulWidget {
  const RefreshOnOpen({super.key, required this.loaders, required this.child});

  final List<Future<void> Function()> loaders;
  final Widget child;

  @override
  State<RefreshOnOpen> createState() => _RefreshOnOpenState();
}

class _RefreshOnOpenState extends State<RefreshOnOpen> {
  @override
  void initState() {
    super.initState();
    for (final load in widget.loaders) {
      load();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// O que mostrar quando uma lista vinda da API está vazia:
/// carregando, erro (com "Tentar de novo") ou o estado vazio da tela.
class LoadState extends StatelessWidget {
  const LoadState({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.empty,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final message = error;
    if (message == null) {
      // Puxar para baixo também recarrega a lista vazia.
      return RefreshIndicator(
        onRefresh: () async => onRetry(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: constraints.maxHeight, child: empty),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: AppColors.iconMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
