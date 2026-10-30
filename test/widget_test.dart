import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:research_project/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FruitExportApp()));

    // Verify that the title is on the screen.
    expect(find.text('Fruit Export AI System'), findsOneWidget);
  });
}
