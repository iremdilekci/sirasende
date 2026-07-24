import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_success_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_success_screen.dart';

void main() {
  group('AppointmentSuccessScreen Widget Tests', () {
    const dummyArgs = AppointmentSuccessArgs(
      businessName: 'Berber Ahmet',
      appointmentDate: '2026-07-22',
      startTime: '09:00',
      endTime: '09:30',
      status: 'pending',
    );

    Widget createWidgetUnderTest({AppointmentSuccessArgs args = dummyArgs}) {
      return MaterialApp(home: AppointmentSuccessScreen(args: args));
    }

    testWidgets(
      'should render confirmation details correctly with translated status',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('Randevunuz Oluşturuldu'), findsOneWidget);
        expect(
          find.text('Randevu talebiniz işletmeye iletildi.'),
          findsOneWidget,
        );
        expect(find.text('Berber Ahmet'), findsOneWidget);
        expect(find.text('22 Temmuz 2026'), findsOneWidget);
        expect(find.text('09:00 – 09:30'), findsOneWidget);
        expect(
          find.text('Onay Bekliyor'),
          findsOneWidget,
        ); // Translated from 'pending'
        expect(find.text('Ana sayfaya dön'), findsOneWidget);
      },
    );

    testWidgets('should translate other statuses correctly', (
      WidgetTester tester,
    ) async {
      const argsConfirmed = AppointmentSuccessArgs(
        businessName: 'Berber Ahmet',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        endTime: '09:30',
        status: 'confirmed',
      );

      await tester.pumpWidget(createWidgetUnderTest(args: argsConfirmed));
      expect(find.text('Onaylandı'), findsOneWidget);
    });

    testWidgets('should not overflow on small screen sizes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
