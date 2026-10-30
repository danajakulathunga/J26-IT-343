import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_routes.dart';
import '../features/home/home_routes.dart';
import '../features/identification/presentation/identification_routes.dart';
import '../features/defect_detection/presentation/defect_detection_routes.dart';
import '../features/shelf_life/presentation/shelf_life_routes.dart';
import '../features/traceability/presentation/traceability_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      ...authRoutes,
      ...homeRoutes,
      ...identificationRoutes,
      ...defectDetectionRoutes,
      ...shelfLifeRoutes,
      ...traceabilityRoutes,
    ],
  );
});
