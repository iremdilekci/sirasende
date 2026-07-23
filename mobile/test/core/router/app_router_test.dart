import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/core/router/app_router.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_form_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_success_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_success_screen.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/widgets/business_card.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_appointments_screen.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business> businesses = [];
  Business? business;

  @override
  Future<List<Business>> getBusinesses() async => businesses;

  @override
  Future<Business> getBusinessBySlug(String slug) async => business!;

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async => [];

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
  }) => throw UnimplementedError();
}

class FakeAuthController extends AuthController {
  AdminUser? userValue;

  @override
  FutureOr<AdminUser?> build() async {
    return userValue;
  }

  void setUser(AdminUser? user) {
    state = AsyncValue.data(user);
  }
}

class FakeAppointmentRepository implements AppointmentRepository {
  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    throw UnimplementedError();
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
}

void main() {
  group('GoRouter Tests', () {
    late FakeBusinessRepository fakeRepo;
    late FakeAuthController fakeAuthController;

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

    const dummyAdmin = AdminUser(
      id: 'u1',
      businessId: 'b1',
      username: 'Ahmet Barber',
      email: 'a@a.com',
      isActive: true,
    );

    setUp(() {
      fakeRepo = FakeBusinessRepository();
      fakeRepo.businesses = [dummyBusiness];
      fakeRepo.business = dummyBusiness;
      fakeAuthController = FakeAuthController();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          businessRepositoryProvider.overrideWithValue(fakeRepo),
          authControllerProvider.overrideWith(() => fakeAuthController),
          appointmentRepositoryProvider.overrideWithValue(
            FakeAppointmentRepository(),
          ),
        ],
        child: const SiraSendeApp(),
      );
    }

    testWidgets(
      'should load role selection screen on root path when unauthenticated',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.byType(RoleSelectionScreen), findsOneWidget);
      },
    );

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

    testWidgets(
      'should load admin login screen on /admin/login path when unauthenticated',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go('/admin/login');
        await tester.pumpAndSettle();

        expect(find.byType(AdminLoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      'should redirect /admin/home to /admin/login when unauthenticated',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go('/admin/home');
        await tester.pumpAndSettle();

        // Redirects to login!
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(AdminHomeScreen), findsNothing);
      },
    );

    testWidgets(
      'should redirect /admin/login to /admin/home when authenticated',
      (WidgetTester tester) async {
        fakeAuthController.userValue = dummyAdmin;

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go('/admin/login');
        await tester.pumpAndSettle();

        // Redirects to home!
        expect(find.byType(AdminHomeScreen), findsOneWidget);
        expect(find.byType(AdminLoginScreen), findsNothing);
      },
    );

    testWidgets(
      'should load appointment form screen on nested path with extra arguments',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go(
          '/customer/businesses/berber-ahmet/appointment',
          extra: const AppointmentFormArgs(
            businessSlug: 'berber-ahmet',
            businessName: 'Berber Ahmet',
            date: '2026-07-22',
            startTime: '09:00',
            endTime: '09:30',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppointmentFormScreen), findsOneWidget);
        expect(find.text('Randevu Bilgileri'), findsOneWidget);
      },
    );

    testWidgets(
      'should load appointment success screen on nested path with success arguments',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go(
          '/customer/appointment/success',
          extra: const AppointmentSuccessArgs(
            businessName: 'Berber Ahmet',
            appointmentDate: '2026-07-22',
            startTime: '09:00',
            endTime: '09:30',
            status: 'pending',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppointmentSuccessScreen), findsOneWidget);
        expect(find.text('Randevunuz Oluşturuldu'), findsOneWidget);
      },
    );

    testWidgets(
      'should load fallback error screen when success path has invalid argument type',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        // Pass wrong extra type
        router.go(
          '/customer/appointment/success',
          extra: 'invalid_args_string',
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppointmentSuccessScreen), findsNothing);
        expect(find.text('Geçersiz sayfa parametreleri.'), findsOneWidget);
      },
    );

    testWidgets(
      'should load admin appointments screen on nested path /admin/home/appointments when authenticated',
      (WidgetTester tester) async {
        fakeAuthController.userValue = dummyAdmin;
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);

        router.go('/admin/home/appointments');
        await tester.pumpAndSettle();

        expect(find.byType(AdminAppointmentsScreen), findsOneWidget);
        expect(find.text('Randevularım'), findsOneWidget);
      },
    );

    testWidgets(
      'should navigate from admin home to admin appointments screen on card tap',
      (WidgetTester tester) async {
        fakeAuthController.userValue = dummyAdmin;
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SiraSendeApp)),
        );
        final router = container.read(appRouterProvider);
        router.go('/admin/home');
        await tester.pumpAndSettle();

        // Tap on the Randevuları Görüntüle button
        final randevularCard = find.text('Randevuları Görüntüle');
        expect(randevularCard, findsOneWidget);
        await tester.ensureVisible(randevularCard);
        await tester.tap(randevularCard);
        await tester.pumpAndSettle();

        // Should be on appointments screen
        expect(find.byType(AdminAppointmentsScreen), findsOneWidget);
        expect(find.text('Randevularım'), findsOneWidget);
      },
    );
  });
}
