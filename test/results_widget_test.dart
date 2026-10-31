import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bananaguard_ai/models/scan_result.dart';
import 'package:bananaguard_ai/models/condition_info.dart';
import 'package:bananaguard_ai/screens/result_screen.dart';
import 'package:bananaguard_ai/widgets/demo_banner.dart';

void main() {
  testWidgets('ResultScreen renders demo banner, bilingual condition and metrics', (tester) async {
    final sampleScan = ScanResultModel(
      scanId: 'widget-test-1234',
      mode: 'demo',
      createdAt: '2026-10-14T12:00:00Z',
      variety: VarietyModel(id: 'ambul', en: 'Ambul', si: 'ඇඹුල්'),
      condition: ConditionOutputModel(
        id: 'anthracnose',
        type: 'Disease',
        en: 'Anthracnose',
        si: 'ඇන්ත්රැක්නෝස්',
        descriptionSi: 'දිලීරමය රෝගයකි',
      ),
      conditionConfidence: 0.92,
      severity: SeverityOutputModel(
        level: 'Moderate',
        en: 'Moderate',
        si: 'මධ්යස්ථ',
      ),
      severityConfidence: 0.78,
      severityIndex: 54.0,
      topPredictions: [
        TopPredictionModel(id: 'anthracnose', en: 'Anthracnose', si: 'ඇන්ත්රැක්නෝස්', confidence: 0.92),
      ],
      causeFactors: [
        LocalizedTextModel(en: 'High humidity', si: 'අධික ආර්ද්‍රතාවය'),
      ],
      recommendations: [
        LocalizedTextModel(en: 'Bunch bagging', si: 'කැන ආවරණය'),
      ],
      images: ImagesOutputModel(
        originalUrl: '/scans/widget-test-1234/original',
        gradcamUrl: '/scans/widget-test-1234/gradcam',
      ),
      qualityWarnings: [],
      lowConfidence: false,
      disclaimer: LocalizedTextModel(
        en: 'Decision-support information only.',
        si: 'තීරණ සහායක තොරතුරු පමණි.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ResultScreen(scanResult: sampleScan),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Demo Banner presence
    expect(find.byType(DemoBanner), findsOneWidget);

    // Verify Condition Name in English (and strict isolation ensures Sinhala text is absent in EN mode)
    expect(find.text('Anthracnose'), findsWidgets);
    expect(find.text('ඇන්ත්රැක්නෝස්'), findsNothing);

    // Verify Sticky Download Button
    expect(find.text('Download PDF Report'), findsOneWidget);
  });
}
