import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/business/presentation/widgets/business_card.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business>? businessesResult;
  Object? error;
  int getCount = 0;
  List<BusinessSchedule>? lastUpdateSchedules;

  @override
  Future<List<Business>> getBusinesses() async {
    getCount++;
    if (error != null) throw error!;
    return businessesResult ?? [];
  }

  @override
  Future<Business> getBusinessBySlug(String slug) {
    throw UnimplementedError();
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async {
    return [];
  }

  @override
  Future<Business> getAdminBusiness() => throw UnimplementedError();

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
    lastUpdateSchedules = schedules;
    if (error != null) throw error!;
    return Business(
      id: '1',
      name: name,
      slug: 'berber-ahmet',
      description: description,
      phone: phone,
      address: address,
      workingStartTime: workingStartTime,
      workingEndTime: workingEndTime,
      slotDurationMinutes: slotDurationMinutes ?? 30,
      isActive: true,
    );
  }
}

void main() {
  group('CustomerBusinessListScreen Tests', () {
    late FakeBusinessRepository fakeRepo;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Kuafor Banu',
      slug: 'kuafor-banu',
      address: 'Nisantasi, Istanbul',
      phone: '+902120000000',
      slotDurationMinutes: 45,
      isActive: true,
    );

    setUp(() {
      fakeRepo = FakeBusinessRepository();
    });

    Widget createWidgetUnderTest() {
      final router = GoRouter(
        initialLocation: '/customer',
        routes: [
          GoRoute(
            path: '/customer',
            name: RouteNames.customerHome,
            builder: (context, state) => const CustomerBusinessListScreen(),
          ),
          GoRoute(
            path: '/customer/businesses/:slug',
            name: RouteNames.customerBusinessDetail,
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );
      return ProviderScope(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('should show loading indicator on initial fetch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('İşletmeler yükleniyor...'), findsOneWidget);
      expect(find.byType(BusinessCard), findsNothing);
    });

    testWidgets('should render business list when fetch is successful', (
      WidgetTester tester,
    ) async {
      fakeRepo.businessesResult = [dummyBusiness];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.byType(BusinessCard), findsOneWidget);
      expect(find.text('Kuafor Banu'), findsOneWidget);
      expect(find.text('Nisantasi, Istanbul'), findsOneWidget);
    });

    testWidgets('should render empty state when list is empty', (
      WidgetTester tester,
    ) async {
      fakeRepo.businessesResult = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.byType(BusinessCard), findsNothing);
      expect(find.text('Henüz işletme bulunmuyor'), findsOneWidget);
      expect(
        find.text('Aktif işletmeler eklendiğinde burada görünecek.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'should render error state with retry button when fetch fails',
      (WidgetTester tester) async {
        fakeRepo.error = const AppException(
          message: 'Baglanti hatasi olustu.',
          code: 'CONN',
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(AppLoadingIndicator), findsNothing);
        expect(find.text('Hata Oluştu'), findsOneWidget);
        expect(find.text('Baglanti hatasi olustu.'), findsOneWidget);
        expect(find.text('Tekrar Dene'), findsOneWidget);

        // Tap retry
        final initialCount = fakeRepo.getCount;
        expect(initialCount, greaterThan(0));
        await tester.tap(find.text('Tekrar Dene'));
        await tester.pump();

        // Should initiate another fetch call
        expect(fakeRepo.getCount, greaterThan(initialCount));
      },
    );

    testWidgets('should refresh list on pull to refresh', (
      WidgetTester tester,
    ) async {
      fakeRepo.businessesResult = [dummyBusiness];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final initialCount = fakeRepo.getCount;
      expect(initialCount, greaterThan(0));

      // Drag ListView down to refresh
      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pump(); // Start refresh animation
      await tester.pump(
        const Duration(seconds: 1),
      ); // Wait for animation to settle
      await tester.pumpAndSettle();

      expect(fakeRepo.getCount, greaterThan(initialCount));
    });

    testWidgets(
      'tapping a card in the list navigates successfully without throwing exceptions',
      (WidgetTester tester) async {
        fakeRepo.businessesResult = [dummyBusiness];

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BusinessCard));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('should not overflow on small screen layout with long texts', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      fakeRepo.businessesResult = [
        const Business(
          id: '1',
          name: 'Cok Uzun Isimli Isletme Test Basligi Altinda Cizilecektir',
          slug: 'long-slug',
          address:
              'Kadikoy Caferaga Mahallesi Caferaga Cikmazi Sokak No: 12 Kat: 4 Daire: 8, Istanbul',
          phone: '+905555555555',
          slotDurationMinutes: 180,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
