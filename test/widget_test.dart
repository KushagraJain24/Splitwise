import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitwise/main.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splitwise App smoke test - verifies compilation and initial auth screens boot', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Pump frames to complete loading phase and splash transition
    await tester.pumpAndSettle();

    // Verify we land on the Firebase Setup Required screen (since Firebase is disabled in test runner)
    expect(find.text('Firebase Setup Required'), findsOneWidget);

    // Scroll the bypass button into view
    final bypassButton = find.text('PROCEED TO OFFLINE SANDBOX');
    await tester.ensureVisible(bypassButton);
    await tester.pumpAndSettle();

    // Tap the bypass button to proceed to the mock sandbox
    await tester.tap(bypassButton);
    await tester.pumpAndSettle();

    // Verify we land on the Login Screen since no user is authenticated
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('S P L I T W I S E'), findsOneWidget);
  });
}
