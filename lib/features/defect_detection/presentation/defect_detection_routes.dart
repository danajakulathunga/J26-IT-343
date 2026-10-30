import 'package:go_router/go_router.dart';
import 'screens/defect_detection_screen.dart';

final defectDetectionRoutes = [
  GoRoute(
    path: '/defect-detection',
    builder: (context, state) => const DefectDetectionScreen(),
  ),
];
