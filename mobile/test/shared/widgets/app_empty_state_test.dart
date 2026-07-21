import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';

void main() {
  group('AppEmptyState Tests', () {
    testWidgets('should render title and message correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'No Data',
              message: 'Please try again later.',
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Please try again later.'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('should render icon when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(title: 'Empty List', icon: Icons.list),
          ),
        ),
      );

      expect(find.text('Empty List'), findsOneWidget);
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets(
      'should render action button and handle callbacks when both label and handler are provided',
      (WidgetTester tester) async {
        var triggered = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppEmptyState(
                title: 'Retry Connection',
                actionLabel: 'Refresh',
                onAction: () => triggered = true,
              ),
            ),
          ),
        );

        expect(find.byType(AppButton), findsOneWidget);
        expect(find.text('Refresh'), findsOneWidget);

        await tester.tap(find.text('Refresh'));
        await tester.pump();

        expect(triggered, isTrue);
      },
    );

    test(
      'should throw assertion error when only actionLabel is provided without onAction',
      () {
        expect(
          () => AppEmptyState(title: 'Error', actionLabel: 'Tap'),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'should throw assertion error when only onAction is provided without actionLabel',
      () {
        expect(
          () => AppEmptyState(title: 'Error', onAction: () {}),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
