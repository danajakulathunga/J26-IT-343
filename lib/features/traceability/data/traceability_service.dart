import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';

// Service interface
abstract class TraceabilityService {
  Future<Map<String, dynamic>> checkTraceability(String qrData);
}

// Mock implementation
class MockTraceabilityService implements TraceabilityService {
  @override
  Future<Map<String, dynamic>> checkTraceability(String qrData) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    return {
      'batch_id': 'BATCH-10293',
      'qr_data': qrData,
      'status': 'In Transit to Port',
    };
  }
}

// Real API implementation
class ApiTraceabilityService implements TraceabilityService {
  @override
  Future<Map<String, dynamic>> checkTraceability(String qrData) async {
    // TODO: implement API call using ApiClient.instance.post('/traceability')
    throw UnimplementedError();
  }
}

// Riverpod provider for the service
final traceabilityServiceProvider = Provider<TraceabilityService>((ref) {
  if (AppConfig.useMockApi) {
    return MockTraceabilityService();
  } else {
    return ApiTraceabilityService();
  }
});
