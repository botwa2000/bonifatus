import 'package:flutter_test/flutter_test.dart';

import 'package:bonifatus/main.dart';

void main() {
  testWidgets('App starts and shows Hello text', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that "Hello" is shown on the screen.
    expect(find.text('Hello'), findsOneWidget);
  });
}
