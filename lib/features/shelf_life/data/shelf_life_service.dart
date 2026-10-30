import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';

// Service interface
abstract class ShelfLifeService {
  Future<Map<String, dynamic>> predictShelfLife(String imagePath);
}

// Mock implementation
class MockShelfLifeService implements ShelfLifeService {
  @override
  Future<Map<String, dynamic>> predictShelfLife(String imagePath) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return {
      'remaining_days': 5,
      'confidence': 0.92,
    };
  }
}

// Real API implementation
class ApiShelfLifeService implements ShelfLifeService {
  @override
  Future<Map<String, dynamic>> predictShelfLife(String imagePath) async {
    // TODO: implement API call using ApiClient.instance.post('/shelf-life')
    throw UnimplementedError();
  }
}

// Riverpod provider for the service
final shelfLifeServiceProvider = Provider<ShelfLifeService>((ref) {
  if (AppConfig.useMockApi) {
    return MockShelfLifeService();
  } else {
    return ApiShelfLifeService();
  }
});
