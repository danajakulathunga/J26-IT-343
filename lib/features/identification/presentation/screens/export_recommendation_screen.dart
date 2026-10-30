import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/result_card.dart';
import '../../data/identification_service.dart';
import '../../data/models/country_recommendation.dart';

final recommendationsProvider = FutureProvider.family<List<CountryRecommendation>, String>((ref, variety) async {
  final service = ref.watch(identificationServiceProvider);
  return service.getExportRecommendations(variety);
});

class ExportRecommendationScreen extends ConsumerWidget {
  final String variety;
  const ExportRecommendationScreen({super.key, required this.variety});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recommendationsProvider(variety));

    return Scaffold(
      appBar: AppBar(title: Text('Recommendations for $variety')),
      body: state.when(
        loading: () => const LoadingView(message: 'Loading export data...'),
        error: (err, _) => ErrorView(error: err.toString(), onRetry: () => ref.refresh(recommendationsProvider(variety))),
        data: (recommendations) {
          if (recommendations.isEmpty) {
            return const Center(child: Text('No recommendations found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ResultCard(
                  title: 'Rank ${index + 1}: ${rec.country}',
                  data: rec.toJson(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
