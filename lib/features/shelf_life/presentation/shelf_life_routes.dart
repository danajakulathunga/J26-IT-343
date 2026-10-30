import 'package:go_router/go_router.dart';
import 'screens/shelf_life_screen.dart';

final shelfLifeRoutes = [
  GoRoute(
    path: '/shelf-life',
    builder: (context, state) => const ShelfLifeScreen(),
  ),
];
