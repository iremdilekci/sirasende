import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/core/router/app_router.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_placeholder_screen.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/widgets/business_card.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business> businesses = [];
  Business? business;

  @override
  Future<List<Business>> getBusinesses() async => businesses;

  @override
  Future<Business> getBusinessBySlug(String slug) async => business!;
}

void main() {
  group('GoRouter Tests', () {
    late FakeBusinessRepository fakeRepo;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Berber Ahmet',
      slug: 'berber-ahmet',
      address: 'Kadikoy, Istanbul',
      phone: '+905555555555',
      slotDurationMinutes: 30,
      isActive: true,
      workingStartTime: '09:00:00',
      workingEndTime: '18:00:00',
    );

    setUp(() {
      fakeRepo = FakeBusinessRepository();
      fakeRepo.businesses = [dummyBusiness];
      fakeRepo.business = dummyBusiness;
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const SiraSendeApp(),
      );
    }

    testWidgets('should load role selection screen on root path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });

    testWidgets('should load customer business list on /customer path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/customer');
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBusinessListScreen), findsOneWidget);
    });

    testWidgets('should load business detail screen on nested path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/customer/businesses/berber-ahmet');
      await tester.pumpAndSettle();

      expect(find.byType(BusinessDetailScreen), findsOneWidget);
      expect(find.text('Berber Ahmet'), findsWidgets);
    });

    testWidgets('should navigate from list to detail on card click and back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      // Go to customer list
      router.go('/customer');
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBusinessListScreen), findsOneWidget);

      // Tap on the business card
      await tester.tap(find.byType(BusinessCard));
      await tester.pumpAndSettle();

      // Should be on detail screen
      expect(find.byType(BusinessDetailScreen), findsOneWidget);

      // Tap back button
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should return to list screen
      expect(find.byType(CustomerBusinessListScreen), findsOneWidget);
    });

    testWidgets('should load admin login placeholder on /admin/login path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/admin/login');
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginPlaceholderScreen), findsOneWidget);
    });
  });
}
