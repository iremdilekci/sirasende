import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class FakeAuthController extends AuthController {
  @override
  FutureOr<AdminUser?> build() async {
    return null;
  }
}

class FakeBusinessRepository implements BusinessRepository {
  List<BusinessSchedule>? lastUpdateSchedules;

  @override
  Future<List<Business>> getBusinesses() async {
    return [
      const Business(
        id: '1',
        name: 'Berber Ahmet',
        slug: 'berber-ahmet',
        address: 'Kadikoy, Istanbul',
        phone: '+905555555555',
        slotDurationMinutes: 30,
        isActive: true,
        workingStartTime: '09:00:00',
        workingEndTime: '18:00:00',
      ),
    ];
  }

  @override
  Future<Business> getBusinessBySlug(String slug) async {
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
  group('RoleSelectionScreen Tests', () {
    late FakeBusinessRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeBusinessRepository();
    });

    testWidgets('should render onboarding components correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => FakeAuthController()),
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(home: Scaffold(body: RoleSelectionScreen())),
        ),
      );

      // Wait for initial async notifier build to complete
      await tester.pumpAndSettle();

      expect(find.text('SıraSende'), findsOneWidget);
      expect(
        find.text('Randevunuzu kolayca alın veya işletmenizi yönetin.'),
        findsOneWidget,
      );
      expect(find.text('Müşteri olarak devam et'), findsOneWidget);
      expect(find.text('Esnaf olarak devam et'), findsOneWidget);
    });

    testWidgets('should fit within small screen size without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => FakeAuthController()),
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(home: Scaffold(body: RoleSelectionScreen())),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'should navigate to customer home when customer button is tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(() => FakeAuthController()),
              businessRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const SiraSendeApp(),
          ),
        );
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => FakeAuthController()),
            businessRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const SiraSendeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap esnaf button
      await tester.tap(find.text('Esnaf olarak devam et'));
      await tester.pumpAndSettle();

      // Verify we arrived at the admin login screen
      expect(find.text('İşletme Girişi'), findsWidgets);
    });
  });
}
