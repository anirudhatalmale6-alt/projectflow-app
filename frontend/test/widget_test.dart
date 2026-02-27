import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ProjectManagerApp());
    // Verify splash screen renders
    expect(find.text('ProjectFlow'), findsOneWidget);
  });
}
