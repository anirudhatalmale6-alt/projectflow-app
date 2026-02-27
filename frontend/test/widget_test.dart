import 'package:flutter_test/flutter_test.dart';
import 'package:duozzflow/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const DuozzFlowApp());
    // Verify splash screen renders
    expect(find.text('Duozz Flow'), findsOneWidget);
  });
}
