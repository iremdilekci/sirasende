import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/presentation/widgets/business_card.dart';

void main() {
  group('BusinessCard Widget Tests', () {
    const defaultBusiness = Business(
      id: '1',
      name: 'Berber Ahmet',
      slug: 'berber-ahmet',
      address: 'Kadikoy, Istanbul',
      phone: '+905555555555',
      slotDurationMinutes: 30,
      isActive: true,
    );

    testWidgets('should render business name and slot duration correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BusinessCard(business: defaultBusiness)),
        ),
      );

      expect(find.text('Berber Ahmet'), findsOneWidget);
      expect(find.text('Randevu süresi: 30 dakika'), findsOneWidget);
    });

    testWidgets('should render address and phone when they are present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BusinessCard(business: defaultBusiness)),
        ),
      );

      expect(find.text('Kadikoy, Istanbul'), findsOneWidget);
      expect(find.text('+905555555555'), findsOneWidget);
    });

    testWidgets(
      'should not render address or phone when they are null or empty',
      (WidgetTester tester) async {
        const minimalBusiness = Business(
          id: '2',
          name: 'Sade Salon',
          slug: 'sade-salon',
          slotDurationMinutes: 45,
          isActive: true,
          address: '', // empty
          phone: null, // null
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: BusinessCard(business: minimalBusiness)),
          ),
        );

        expect(find.byIcon(Icons.location_on_outlined), findsNothing);
        expect(find.byIcon(Icons.phone_outlined), findsNothing);
      },
    );

    testWidgets('should trigger onTap callback when clicked', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessCard(
              business: defaultBusiness,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('should not crash when onTap is null and card is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BusinessCard(business: defaultBusiness)),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      // No exception thrown is success
    });

    testWidgets('should not overflow on small screen sizes with long text', (
      WidgetTester tester,
    ) async {
      // Set physical size to a small screen e.g. 320x568
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      const longTextBusiness = Business(
        id: '3',
        name:
            'Mehmet ve Ahmet Kardesler Sac Tasarim Ve Guzellik Kompleksi Cilt Bakim Merkezi A.S.',
        slug: 'mehmet-ve-ahmet',
        address:
            'Caferaga Mahallesi General Asim Gunduz Caddesi Altin Sokak Altin Han No: 45 Daire: 12 Kadikoy, Istanbul, Turkiye',
        phone: '+905555555555',
        slotDurationMinutes: 120,
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BusinessCard(business: longTextBusiness),
            ),
          ),
        ),
      );

      // Verify no RenderFlex overflow exception
      expect(tester.takeException(), isNull);

      // Reset test window size
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
