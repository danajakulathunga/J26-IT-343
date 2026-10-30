import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';

// Service interface
abstract class DefectDetectionService {
  Future<Map<String, dynamic>> detectDefects(String imagePath);
}

// Mock implementation
class MockDefectDetectionService implements DefectDetectionService {
  @override
  Future<Map<String, dynamic>> detectDefects(String imagePath) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return {
      'defect_type': 'anthracnose',
      'severity': 'moderate',
      'confidence': 0.88,
      'cause': 'Fungal infection',
    };
  }
}

// Real API implementation
class ApiDefectDetectionService implements DefectDetectionService {
  @override
  Future<Map<String, dynamic>> detectDefects(String imagePath) async {
    // TODO: implement API call using ApiClient.instance.post('/defects')
    throw UnimplementedError();
  }
}

// Riverpod provider for the service
final defectDetectionServiceProvider = Provider<DefectDetectionService>((ref) {
  if (AppConfig.useMockApi) {
    return MockDefectDetectionService();
  } else {
    return ApiDefectDetectionService();
  }
});
