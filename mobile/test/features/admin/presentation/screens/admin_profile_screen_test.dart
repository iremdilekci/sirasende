import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_profile_screen.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';

class FakeBusinessRepository implements BusinessRepository {
  Business? businessResult;
  Object? fetchError;
  Object? updateError;

  int fetchCalls = 0;
  int updateCalls = 0;

  String? lastUpdateName;
  String? lastUpdateDesc;
  String? lastUpdatePhone;
  String? lastUpdateAddress;
  String? lastUpdateStartTime;
  String? lastUpdateEndTime;
  int? lastUpdateSlotDuration;
  List<BusinessSchedule>? lastUpdateSchedules;

  @override
  Future<List<Business>> getBusinesses() async => throw UnimplementedError();

  @override
  Future<Business> getBusinessBySlug(String slug) async =>
      throw UnimplementedError();

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async => throw UnimplementedError();

  @override
  Future<Business> getAdminBusiness() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return businessResult!;
  }

  @override
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  }) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
    lastUpdateName = name;
    lastUpdateDesc = description;
    lastUpdatePhone = phone;
    lastUpdateAddress = address;
    lastUpdateStartTime = workingStartTime;
    lastUpdateEndTime = workingEndTime;
    lastUpdateSlotDuration = slotDurationMinutes;
    lastUpdateSchedules = schedules;

    return Business(
      id: businessResult!.id,
      name: name,
      slug: businessResult!.slug,
      description: description,
      phone: phone,
      address: address,
      workingStartTime: workingStartTime,
      workingEndTime: workingEndTime,
      slotDurationMinutes:
          slotDurationMinutes ?? businessResult!.slotDurationMinutes,
      isActive: businessResult!.isActive,
    );
  }
}

void main() {
  group('AdminProfileScreen Widget Tests', () {
    const dummyBusiness = Business(
      id: '1',
      name: 'Ahmet Barber Shop',
      slug: 'ahmet-barber',
      description: 'The best haircut in town',
      phone: '+905554443322',
      address: 'Kadikoy, Istanbul',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
    );

    late FakeBusinessRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeBusinessRepository();
      fakeRepo.businessResult = dummyBusiness;
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const MaterialApp(home: AdminProfileScreen()),
      );
    }

    testWidgets('should display business profile details when loaded', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Start fetching
      await tester.pump(); // Render data state

      expect(find.text('Profil Yönetimi'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Ahmet Barber Shop'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'The best haircut in town'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, '+905554443322'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Kadikoy, Istanbul'),
        findsOneWidget,
      );

      // Verify opening and closing hours formatting
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);

      // Verify slot duration choice
      expect(find.text('30 Dakika'), findsOneWidget);
    });

    testWidgets('should show validation error when business name is empty', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Enter empty name
      final nameField = find.widgetWithText(TextFormField, 'Ahmet Barber Shop');
      await tester.enterText(nameField, '  ');

      // Tap Save after ensuring visible
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pump(); // trigger validation layout

      expect(find.text('İşletme adı boş olamaz.'), findsOneWidget);
      expect(fakeRepo.updateCalls, 0);
    });

    testWidgets('should show validation error when phone number is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Enter invalid phone
      final phoneField = find.widgetWithText(TextFormField, '+905554443322');
      await tester.enterText(phoneField, 'invalid-phone');

      // Tap Save after ensuring visible
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pump();

      expect(
        find.text('Geçerli bir telefon numarası giriniz.'),
        findsOneWidget,
      );
      expect(fakeRepo.updateCalls, 0);
    });

    testWidgets('should show green snackbar on successful profile update', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Modify fields
      final nameField = find.widgetWithText(TextFormField, 'Ahmet Barber Shop');
      await tester.enterText(nameField, 'Yeni Ahmet Berber');

      final descField = find.widgetWithText(
        TextFormField,
        'The best haircut in town',
      );
      await tester.enterText(descField, 'Yeni aciklama');

      // Tap Save after ensuring visible
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pump(); // start async notification

      // Re-render async callback completions
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.updateCalls, 1);
      expect(fakeRepo.lastUpdateName, 'Yeni Ahmet Berber');
      expect(fakeRepo.lastUpdateDesc, 'Yeni aciklama');

      // Check success snackbar
      expect(
        find.text('Profil bilgileri başarıyla güncellendi.'),
        findsOneWidget,
      );
    });

    testWidgets('should show red snackbar on update failure', (tester) async {
      fakeRepo.updateError = const AppException(
        message: 'Girdiğiniz telefon numarası zaten kayıtlı.',
        code: 'PHONE_TAKEN',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      // Tap Save after ensuring visible
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.updateCalls, 1);
      expect(
        find.text('Girdiğiniz telefon numarası zaten kayıtlı.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'should display error screen with retry button when loading fails',
      (tester) async {
        fakeRepo.fetchError = const AppException(
          message: 'Profil bilgileri sunucudan yüklenemedi.',
          code: 'LOAD_ERROR',
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pumpAndSettle(); // Settle all async / future states

        expect(
          find.text('Profil bilgileri sunucudan yüklenemedi.'),
          findsOneWidget,
        );
        expect(find.text('Tekrar Dene'), findsOneWidget);

        // Resolve error and tap retry
        fakeRepo.fetchError = null;
        await tester.tap(find.text('Tekrar Dene'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextFormField, 'Ahmet Barber Shop'),
          findsOneWidget,
        );
      },
    );
  });
}
