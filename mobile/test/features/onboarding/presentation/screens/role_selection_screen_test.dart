import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';

void main() {
  group('RoleSelectionScreen Tests', () {
    testWidgets('should render onboarding components correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: RoleSelectionScreen())),
        ),
      );

      expect(find.text('SıraSende'), findsOneWidget);
      expect(
        find.text('Randevunuzu kolayca oluşturun veya işletmenizi yönetin.'),
        findsOneWidget,
      );
      expect(find.text('Müşteri olarak devam et'), findsOneWidget);
      expect(find.text('Esnaf girişi'), findsOneWidget);
    });

    testWidgets('should fit within small screen size without overflow', (
      WidgetTester tester,
    ) async {
      // Set to a very small mobile physical size
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: RoleSelectionScreen())),
        ),
      );

      // Verify no overflow errors are printed or detected
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'should navigate to customer home when customer button is tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));
        await tester.pumpAndSettle();

        // Tap customer button
        await tester.tap(find.text('Müşteri olarak devam et'));
        await tester.pumpAndSettle();

        // Verify we arrived at the customer list screen
        expect(find.text('İşletmeler'), findsOneWidget);
        expect(find.byType(CustomerBusinessListScreen), findsOneWidget);
      },
    );

    testWidgets('should navigate to admin login when esnaf button is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));
      await tester.pumpAndSettle();

      // Tap esnaf button
      await tester.tap(find.text('Esnaf girişi'));
      await tester.pumpAndSettle();

      // Verify we arrived at the admin login placeholder screen
      expect(find.text('Esnaf Girişi'), findsOneWidget);
      expect(
        find.text('Esnaf giriş ekranı sonraki sprint bölümünde eklenecek.'),
        findsOneWidget,
      );
    });
  });
}
