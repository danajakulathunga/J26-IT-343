import 'package:go_router/go_router.dart';
import 'screens/traceability_screen.dart';

final traceabilityRoutes = [
  GoRoute(
    path: '/traceability',
    builder: (context, state) => const TraceabilityScreen(),
  ),
];
