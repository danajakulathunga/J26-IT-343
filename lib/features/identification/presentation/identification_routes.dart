import 'package:go_router/go_router.dart';
import 'screens/identification_screen.dart';
import 'screens/admin_model_center_screen.dart';
import 'screens/export_recommendation_screen.dart';
import 'screens/market_trends_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/dataset_training_screen.dart';
import 'screens/model_report_screen.dart';

final identificationRoutes = [
  GoRoute(
    path: '/identification',
    builder: (context, state) => const IdentificationScreen(),
    routes: [
      GoRoute(
        path: 'admin-models',
        builder: (context, state) => const AdminModelCenterScreen(),
      ),
      GoRoute(
        path: 'recommendations',
        builder: (context, state) {
          final variety = state.extra as String? ?? 'Unknown';
          return ExportRecommendationScreen(variety: variety);
        },
      ),
      GoRoute(
        path: 'trends',
        builder: (context, state) => const MarketTrendsScreen(),
      ),
      GoRoute(
        path: 'alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: 'training',
        builder: (context, state) => const DatasetTrainingScreen(),
      ),
      GoRoute(
        path: 'models/:versionId/report',
        builder: (context, state) {
          final versionId = state.pathParameters['versionId'] ?? 'active';
          final task = state.uri.queryParameters['task'] ?? 'variety';
          return ModelReportScreen(versionId: versionId, task: task);
        },
      ),
    ],
  ),
];
