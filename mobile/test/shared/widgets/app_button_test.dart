import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';

void main() {
  group('AppButton Tests', () {
    testWidgets('should render label text correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppButton(label: 'Submit')),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should trigger onPressed callback when clicked', (
      WidgetTester tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'Click Me', onPressed: () => pressed = true),
          ),
        ),
      );

      await tester.tap(find.text('Click Me'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('should not trigger callback when onPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppButton(label: 'Disabled', onPressed: null)),
        ),
      );

      // Verify button is disabled or at least no gesture crashes.
      final buttonFinder = find.byType(FilledButton);
      final FilledButton button = tester.widget(buttonFinder);
      expect(button.enabled, isFalse);
    });

    testWidgets(
      'should show loading indicator and disable click when isLoading is true',
      (WidgetTester tester) async {
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppButton(
                label: 'Load',
                isLoading: true,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Load'), findsNothing);

        // Check if button is disabled in UI code.
        final buttonFinder = find.byType(FilledButton);
        final FilledButton button = tester.widget(buttonFinder);
        expect(button.enabled, isFalse);
        expect(pressed, isFalse);
      },
    );
  });
}
