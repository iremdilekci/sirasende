import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

void main() {
  group('AppLoadingIndicator Tests', () {
    testWidgets('should render progress indicator without message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppLoadingIndicator())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('should render progress indicator with message when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoadingIndicator(message: 'Yükleniyor...')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Yükleniyor...'), findsOneWidget);
    });
  });
}
