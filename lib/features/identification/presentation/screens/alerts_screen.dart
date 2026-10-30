import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../data/identification_service.dart';

final alertsProvider = FutureProvider((ref) async {
  final service = ref.watch(identificationServiceProvider);
  return service.getMarketAlerts();
});

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Market Alerts')),
      body: state.when(
        loading: () => const LoadingView(message: 'Loading alerts...'),
        error: (err, _) => ErrorView(error: err.toString(), onRetry: () => ref.refresh(alertsProvider)),
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts at this time.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.amber),
                  title: Text(alert.type),
                  subtitle: Text('${alert.message}\n${alert.createdAt}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
