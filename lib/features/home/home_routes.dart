import 'package:go_router/go_router.dart';
import '../identification/presentation/screens/identification_screen.dart';

final homeRoutes = [
  GoRoute(
    path: '/',
    builder: (context, state) => const IdentificationScreen(),
  ),
];
