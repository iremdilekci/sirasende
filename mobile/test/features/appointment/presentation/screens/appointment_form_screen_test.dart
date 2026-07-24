import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_form_screen.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  Appointment? result;
  Object? error;
  int callCount = 0;
  String? lastSlug;
  AppointmentCreateRequest? lastRequest;

  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    callCount++;
    lastSlug = businessSlug;
    lastRequest = request;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  }) async {
    return [];
  }

  @override
  Future<Appointment> updateAppointmentStatus({
    required String id,
    required String status,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Appointment> syncGoogleCalendar({required String id}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('AppointmentFormScreen Widget and Logic Tests', () {
    late FakeAppointmentRepository fakeRepo;

    const dummyArgs = AppointmentFormArgs(
      businessSlug: 'berber-ahmet',
      businessName: 'Berber Ahmet',
      date: '2026-07-22',
      startTime: '09:00',
      endTime: '09:30',
    );

    final dummyAppointment = const Appointment(
      id: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      businessId: 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
      customerName: 'Ahmet Can',
      customerPhone: '05554443322',
      customerNote: null,
      appointmentDate: '2026-07-22',
      startTime: '09:00',
      endTime: '09:30',
      status: 'pending',
      createdAt: '2026-07-22T20:00:00Z',
      updatedAt: '2026-07-22T20:00:00Z',
    );

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
      fakeRepo.result = dummyAppointment;
    });

    Widget createWidgetUnderTest({
      AppointmentFormArgs args = dummyArgs,
      ValueChanged<AppointmentDraft>? onValidSubmit,
      List<dynamic> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appointmentRepositoryProvider.overrideWithValue(fakeRepo),
          ...overrides,
        ],
        child: MaterialApp(
          home: AppointmentFormScreen(args: args, onValidSubmit: onValidSubmit),
        ),
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
        expect(
          find.widgetWithText(FilledButton, 'Randevuyu Oluştur'),
          findsOneWidget,
        );
      },
    );

    testWidgets('should show validation errors when fields are left blank', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final submitButton = find.widgetWithText(
        FilledButton,
        'Randevuyu Oluştur',
      );
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ad soyad alanı zorunludur.'), findsOneWidget);
      expect(find.text('Telefon numarası alanı zorunludur.'), findsOneWidget);
      expect(fakeRepo.callCount, 0); // Form invalid, no submit
    });

    testWidgets('should show validation error for short customer_name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'A',
      );
      final submitButton = find.widgetWithText(
        FilledButton,
        'Randevuyu Oluştur',
      );
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ad soyad en az 2 karakter olmalıdır.'), findsOneWidget);
      expect(fakeRepo.callCount, 0);
    });

    testWidgets('should show validation error for short customer_phone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad Soyad'),
        'Canan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefon Numarası'),
        '1234',
      );
      final submitButton = find.widgetWithText(
        FilledButton,
        'Randevuyu Oluştur',
      );
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Telefon numarası en az 5 karakter olmalıdır.'),
        findsOneWidget,
      );
      expect(fakeRepo.callCount, 0);
    });

    testWidgets(
      'should fire callCount on repository and trigger onValidSubmit',
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

        final submitButton = find.widgetWithText(
          FilledButton,
          'Randevuyu Oluştur',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(fakeRepo.callCount, 1);
        expect(capturedDraft, isNotNull);
        expect(capturedDraft!.customerName, 'Ahmet Can');
      },
    );

    testWidgets(
      'should map 409 Conflict code to custom Turkish error banner with pop option',
      (WidgetTester tester) async {
        fakeRepo.error = const AppException(
          message:
              'Bu saat az önce başka biri tarafından rezerve edildi. Lütfen farklı bir saat seçin.',
          code: 'CONFLICT',
        );

        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad Soyad'),
          'Ayse Yilmaz',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefon Numarası'),
          '05445555555',
        );

        final submitButton = find.widgetWithText(
          FilledButton,
          'Randevuyu Oluştur',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Bu saat artık müsait değil'), findsOneWidget);
        expect(
          find.text(
            'Bu saat az önce başka biri tarafından rezerve edildi. Lütfen farklı bir saat seçin.',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Başka Saat Seç'),
          findsOneWidget,
        );

        // Verify form data remains preserved
        expect(
          find.widgetWithText(TextFormField, 'Ayse Yilmaz'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should show standard error Turkish mapping for 400 Bad Request error',
      (WidgetTester tester) async {
        fakeRepo.error = const AppException(
          message:
              'Randevu bilgileri geçerli değil. Tarih ve saat seçiminizi kontrol edin.',
          code: 'BAD_REQUEST',
        );

        await tester.pumpWidget(createWidgetUnderTest());

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad Soyad'),
          'Ayse Yilmaz',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Telefon Numarası'),
          '05445555555',
        );

        final submitButton = find.widgetWithText(
          FilledButton,
          'Randevuyu Oluştur',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('İşlem Başarısız'), findsOneWidget);
        expect(
          find.text(
            'Randevu bilgileri geçerli değil. Tarih ve saat seçiminizi kontrol edin.',
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'Ayse Yilmaz'),
          findsOneWidget,
        ); // Inputs preserved
      },
    );

    testWidgets('should not overflow layout on small screen size', (
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
