import 'package:flutter_test/flutter_test.dart';
import 'package:bananaguard_ai/providers/scan_provider.dart';

void main() {
  group('ScanState and ScanNotifier State Machine Tests', () {
    test('Initial state is idle with no error and empty progress', () {
      final notifier = ScanNotifier();
      expect(notifier.state.status, ScanStatus.idle);
      expect(notifier.state.isAnalyzing, false);
      expect(notifier.state.isSuccess, false);
      expect(notifier.state.isFailed, false);
      expect(notifier.state.uploadProgress, 0.0);
      expect(notifier.state.errorMessage, isNull);
    });

    test('analyzeImage with no image transitions to failure without hanging', () async {
      final notifier = ScanNotifier();
      final success = await notifier.analyzeImage('en');

      expect(success, false);
      expect(notifier.state.status, ScanStatus.failure);
      expect(notifier.state.isFailed, true);
      expect(notifier.state.isAnalyzing, false);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('cancelAnalysis immediately stops loading and returns to idle', () {
      final notifier = ScanNotifier();
      notifier.cancelAnalysis();

      expect(notifier.state.status, ScanStatus.idle);
      expect(notifier.state.isAnalyzing, false);
    });

    test('reset clears image, variety, errors, and resets to idle', () {
      final notifier = ScanNotifier();
      notifier.reset();

      expect(notifier.state.status, ScanStatus.idle);
      expect(notifier.state.selectedImage, isNull);
      expect(notifier.state.selectedImageBytes, isNull);
      expect(notifier.state.selectedVariety, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.uploadProgress, 0.0);
    });

    test('ScanState helper properties reflect current status accurately', () {
      var state = ScanState(status: ScanStatus.uploading);
      expect(state.isAnalyzing, true);
      expect(state.isSuccess, false);
      expect(state.isFailed, false);

      state = ScanState(status: ScanStatus.analyzing);
      expect(state.isAnalyzing, true);

      state = ScanState(status: ScanStatus.success);
      expect(state.isAnalyzing, false);
      expect(state.isSuccess, true);

      state = ScanState(status: ScanStatus.failure);
      expect(state.isAnalyzing, false);
      expect(state.isFailed, true);
    });
  });
}
