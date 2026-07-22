import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_form_screen.dart';

void main() {
  group('AppointmentFormScreen Widget Tests', () {
    const dummyArgs = AppointmentFormArgs(
      businessSlug: 'berber-ahmet',
      businessName: 'Berber Ahmet',
      date: '2026-07-22',
      startTime: '09:00',
      endTime: '09:30',
    );

    Widget createWidgetUnderTest({
      AppointmentFormArgs args = dummyArgs,
      ValueChanged<AppointmentDraft>? onValidSubmit,
    }) {
      return MaterialApp(
        home: AppointmentFormScreen(args: args, onValidSubmit: onValidSubmit),
      );
    }

    testWidgets(
      'should render selection summary card with Turkish formatted date',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.text('Berber Ahmet'), findsOneWidget);
        expect(
          find.text('22 Temmuz 2026'),
          findsOneWidget,
        ); // Parsed from 2026-07-22
        expect(find.text('09:00 – 09:30'), findsOneWidget);

        expect(find.text('Müşteri Bilgileri'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Ad Soyad'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Telefon Numarası'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'Not (İsteğe Bağlı)'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Devam Et'), findsOneWidget);
      },
    );

    testWidgets('should show validation errors when fields are left blank', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap submit without typing anything
      final submitButton = find.widgetWithText(FilledButton, 'Devam Et');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ad soyad alanı zorunludur.'), findsOneWidget);
      expect(find.text('Telefon numarası alanı zorunludur.'), findsOneWidget);
    });

    testWidgets('should show validation error for short customer_name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Type 1 character name and blank phone
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'A',
      );
      final submitButton = find.widgetWithText(FilledButton, 'Devam Et');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ad soyad en az 2 karakter olmalıdır.'), findsOneWidget);
      expect(find.text('Telefon numarası alanı zorunludur.'), findsOneWidget);
    });

    testWidgets('should show validation error for short customer_phone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Type valid name and 4 characters phone
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Canan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefon Numarası'),
        '1234',
      );
      final submitButton = find.widgetWithText(FilledButton, 'Devam Et');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ad soyad en az 2 karakter olmalıdır.'), findsNothing);
      expect(
        find.text('Telefon numarası en az 5 karakter olmalıdır.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'should fire onValidSubmit with validated draft on successful validation',
      (WidgetTester tester) async {
        AppointmentDraft? capturedDraft;

        await tester.pumpWidget(
          createWidgetUnderTest(
            onValidSubmit: (draft) {
              capturedDraft = draft;
            },
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad Soyad'),
          '  Ahmet Can  ',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefon Numarası'),
          ' +905555555555 ',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Not (İsteğe Bağlı)'),
          ' Sac kesimi olsun. ',
        );

        final submitButton = find.widgetWithText(FilledButton, 'Devam Et');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Ad soyad alanı zorunludur.'), findsNothing);
        expect(find.text('Telefon numarası alanı zorunludur.'), findsNothing);

        expect(capturedDraft, isNotNull);
        expect(capturedDraft!.customerName, 'Ahmet Can'); // Trimmed
        expect(capturedDraft!.customerPhone, '+905555555555'); // Trimmed
        expect(capturedDraft!.customerNote, 'Sac kesimi olsun.'); // Trimmed
        expect(capturedDraft!.businessSlug, 'berber-ahmet');
        expect(capturedDraft!.appointmentDate, '2026-07-22');
        expect(capturedDraft!.startTime, '09:00');
      },
    );

    testWidgets('should handle empty optional note in output draft as null', (
      WidgetTester tester,
    ) async {
      AppointmentDraft? capturedDraft;

      await tester.pumpWidget(
        createWidgetUnderTest(
          onValidSubmit: (draft) {
            capturedDraft = draft;
          },
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Ayse Can',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefon Numarası'),
        '05445555555',
      );
      // Leave note empty

      final submitButton = find.widgetWithText(FilledButton, 'Devam Et');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(capturedDraft, isNotNull);
      expect(capturedDraft!.customerName, 'Ayse Can');
      expect(capturedDraft!.customerPhone, '05445555555');
      expect(capturedDraft!.customerNote, isNull); // Empty note maps to null
    });

    testWidgets('should not overflow on small screen physical sizes', (
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
