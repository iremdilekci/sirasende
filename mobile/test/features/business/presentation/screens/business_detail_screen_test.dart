import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

class FakeBusinessRepository implements BusinessRepository {
  Business? businessResult;
  Object? error;
  int getDetailCount = 0;
  String? lastSlug;

  List<Slot>? slotsResult;
  Completer<List<Slot>>? slotsCompleter;
  Object? slotsError;
  int getSlotsCount = 0;
  String? lastSlotsSlug;
  String? lastSlotsDate;

  @override
  Future<List<Business>> getBusinesses() {
    throw UnimplementedError();
  }

  @override
  Future<Business> getBusinessBySlug(String slug) async {
    getDetailCount++;
    lastSlug = slug;
    if (error != null) throw error!;
    return businessResult!;
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async {
    getSlotsCount++;
    lastSlotsSlug = slug;
    lastSlotsDate = date;
    if (slotsCompleter != null) return slotsCompleter!.future;
    if (slotsError != null) throw slotsError!;
    return slotsResult ?? [];
  }
}

void main() {
  group('BusinessDetailScreen Tests', () {
    late FakeBusinessRepository fakeRepo;

    final dummyBusiness = const Business(
      id: 'd290f1ee-6c54-4b01-90e6-d701748f0851',
      name: 'Berber Ahmet',
      slug: 'berber-ahmet',
      address: 'Kadikoy, Istanbul',
      phone: '+905555555555',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
      createdAt: '2026-07-12T10:00:00Z',
      updatedAt: '2026-07-12T12:00:00Z',
    );

    DateTime testClock() => DateTime(2026, 7, 22, 14, 30);

    setUp(() {
      fakeRepo = FakeBusinessRepository();
    });

    Widget createWidgetUnderTest(String slug) {
      return ProviderScope(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: BusinessDetailScreen(slug: slug, clock: testClock),
        ),
      );
    }

    testWidgets('should show loading indicator on initial detail fetch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('İşletme bilgileri yükleniyor...'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets(
      'should render business details and default test date on success',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsResult = [];

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        expect(find.byType(AppLoadingIndicator), findsNothing);
        expect(find.text('Berber Ahmet'), findsWidgets);
        expect(
          find.text('22 Temmuz 2026'),
          findsOneWidget,
        ); // Default clock date
      },
    );

    testWidgets(
      'should show slots loading indicator only in the slots section',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        final completer = Completer<List<Slot>>();
        fakeRepo.slotsCompleter = completer;

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pump(); // Pump frame without settling

        expect(find.text('Berber Ahmet'), findsWidgets); // Header is resolved
        expect(find.text('Müsait saatler yükleniyor...'), findsOneWidget);

        completer.complete([]);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'should render available slots on success and filter out booked/past slots',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsResult = [
          const Slot(startTime: '09:00', endTime: '09:30', available: true),
          const Slot(
            startTime: '09:30',
            endTime: '10:00',
            available: false,
            reason: 'booked',
          ),
          const Slot(
            startTime: '10:00',
            endTime: '10:30',
            available: false,
            reason: 'past',
          ),
        ];

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        // Should draw available slot
        expect(find.text('09:00'), findsOneWidget);

        // Should NOT draw booked/past slots
        expect(find.text('09:30'), findsNothing);
        expect(find.text('10:00'), findsNothing);
      },
    );

    testWidgets(
      'should show empty state Turkish message when no slots are available',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsResult = []; // No slots

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        expect(find.text('Müsait saat bulunamadı'), findsOneWidget);
        expect(
          find.text(
            'Bu tarih için uygun randevu saati bulunmuyor. Başka bir tarih seçebilirsiniz.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'should show slots error state with retry action in slots section only',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsError = const AppException(
          message: 'Saat yukleme hatasi.',
          code: 'ERR',
        );

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        expect(
          find.text('Berber Ahmet'),
          findsWidgets,
        ); // Header is still there
        expect(find.text('Müsait saatler yüklenemedi'), findsOneWidget);
        expect(find.text('Saat yukleme hatasi.'), findsOneWidget);

        final initialSlotsCount = fakeRepo.getSlotsCount;
        final initialDetailCount = fakeRepo.getDetailCount;

        // Tap retry on slots section
        final retryButton = find.text('Tekrar Dene');
        await tester.ensureVisible(retryButton);
        await tester.tap(retryButton);
        await tester.pump();

        expect(fakeRepo.getSlotsCount, greaterThan(initialSlotsCount));
        expect(
          fakeRepo.getDetailCount,
          initialDetailCount,
        ); // Details NOT refetched
      },
    );

    testWidgets(
      'should update date and fetch slots with new date query param when picker selects a new date',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsResult = [];

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastSlotsDate, '2026-07-22');

        // Tap on Date selection row
        final datePicker = find.text('22 Temmuz 2026');
        await tester.ensureVisible(datePicker);
        await tester.tap(datePicker);
        await tester.pumpAndSettle();

        // Tap OK on the system date picker dialog to choose default selected date or navigate
        // Since we are in tests, picker default points to initialDate (2026-07-22)
        // Let's select the next day if we want to change it, or just tap OK to verify it's open.
        // To select next day (23 July):
        await tester.tap(find.text('23'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastSlotsDate, '2026-07-23');
        expect(find.text('23 Temmuz 2026'), findsOneWidget);
      },
    );

    testWidgets('should not crash or overflow on small screen layout', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeRepo.businessResult = dummyBusiness;
      fakeRepo.slotsResult = [];

      await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'should verify slots have no onTap handlers and no randevu al button exists',
      (WidgetTester tester) async {
        fakeRepo.businessResult = dummyBusiness;
        fakeRepo.slotsResult = [
          const Slot(startTime: '09:00', endTime: '09:30', available: true),
        ];

        await tester.pumpWidget(createWidgetUnderTest('berber-ahmet'));
        await tester.pumpAndSettle();

        // Verify slot chip is rendered
        final slotFinder = find.text('09:00');
        expect(slotFinder, findsOneWidget);

        // Tap on it
        await tester.ensureVisible(slotFinder);
        await tester.tap(slotFinder);
        await tester.pumpAndSettle();

        // Verify no crash occurs
        expect(tester.takeException(), isNull);

        // Verify no CTA/Randevu Al buttons or forms are present
        expect(find.text('Randevu Al'), findsNothing);
        expect(find.byType(TextField), findsNothing);
      },
    );
  });
}
