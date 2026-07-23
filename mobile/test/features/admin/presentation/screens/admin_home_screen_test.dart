import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';

class FakeAuthController extends AuthController {
  AdminUser? valueOverride;
  int logoutCalls = 0;

  @override
  FutureOr<AdminUser?> build() => valueOverride;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue.data(null);
  }
}

class FakeAppointmentRepository implements AppointmentRepository {
  List<Appointment> listResult = [];
  Object? error;
  int listCallCount = 0;
  String? lastDate;

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
    listCallCount++;
    lastDate = date;
    if (error != null) throw error!;
    return listResult;
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
  group('AdminHomeScreen Widget Tests', () {
    const dummyUser = AdminUser(
      id: 'a1b2-c3d4',
      businessId: 'f5cc-3ed5',
      username: 'Ahmet Berber',
      email: 'ahmet@berber.com',
      isActive: true,
    );

    final dummyAppointments = [
      const Appointment(
        id: '1',
        businessId: 'b1',
        customerName: 'A',
        customerPhone: '055',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        endTime: '09:30',
        status: 'pending',
        createdAt: '2026-07-22',
        updatedAt: '2026-07-22',
      ),
      const Appointment(
        id: '2',
        businessId: 'b1',
        customerName: 'B',
        customerPhone: '055',
        appointmentDate: '2026-07-22',
        startTime: '09:30',
        endTime: '10:00',
        status: 'confirmed',
        createdAt: '2026-07-22',
        updatedAt: '2026-07-22',
      ),
      const Appointment(
        id: '3',
        businessId: 'b1',
        customerName: 'C',
        customerPhone: '055',
        appointmentDate: '2026-07-22',
        startTime: '10:00',
        endTime: '10:30',
        status: 'completed',
        createdAt: '2026-07-22',
        updatedAt: '2026-07-22',
      ),
      const Appointment(
        id: '4',
        businessId: 'b1',
        customerName: 'D',
        customerPhone: '055',
        appointmentDate: '2026-07-22',
        startTime: '10:30',
        endTime: '11:00',
        status: 'cancelled',
        createdAt: '2026-07-22',
        updatedAt: '2026-07-22',
      ),
    ];

    late FakeAuthController fakeController;
    late FakeAppointmentRepository fakeRepo;

    setUp(() {
      fakeController = FakeAuthController();
      fakeController.valueOverride = dummyUser;
      fakeRepo = FakeAppointmentRepository();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => fakeController),
          appointmentRepositoryProvider.overrideWithValue(fakeRepo),
          todayDateStringProvider.overrideWithValue('2026-07-22'),
        ],
        child: const MaterialApp(home: AdminHomeScreen()),
      );
    }

    testWidgets(
      'should render welcome details, loading state initially and then success summary',
      (WidgetTester tester) async {
        fakeRepo.listResult = dummyAppointments;

        await tester.pumpWidget(createWidgetUnderTest());

        // Header and loading spinner should be visible
        expect(find.text('Esnaf Paneli'), findsOneWidget);
        expect(find.text('Hoş geldiniz'), findsOneWidget);
        expect(find.text('Ahmet Berber'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        // Loading spinner gone, summary cards visible
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Bugünün Özeti'), findsOneWidget);
        expect(find.text('2026-07-22'), findsOneWidget);

        // Verify counts
        expect(find.text('Toplam Randevu'), findsOneWidget);
        expect(find.text('4'), findsWidgets); // Total + 1 of the status cards
        expect(find.text('Beklemede'), findsOneWidget);
        expect(find.text('Onaylandı'), findsOneWidget);
        expect(find.text('Tamamlandı'), findsOneWidget);
        expect(find.text('İptal Edildi'), findsOneWidget);
        expect(find.text('1'), findsWidgets);

        // Verify redirect button
        expect(find.text('Randevuları Görüntüle'), findsOneWidget);

        // Verify technical IDs are hidden
        expect(find.text('a1b2-c3d4'), findsNothing);
        expect(find.text('f5cc-3ed5'), findsNothing);
      },
    );

    testWidgets('should display empty message state when total is 0', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets); // All counts are 0
      expect(find.text('Bugün için henüz randevu bulunmuyor.'), findsOneWidget);
    });

    testWidgets('should display retry error card when fetch fails', (
      WidgetTester tester,
    ) async {
      fakeRepo.error = const AppException(
        message: 'Oturum doğrulanırken bir hata oluştu.',
        code: 'UNAUTHORIZED',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(
        find.text('Oturum doğrulanırken bir hata oluştu.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Tekrar Dene'), findsOneWidget);

      // Tap retry
      fakeRepo.error = null;
      fakeRepo.listResult = dummyAppointments;
      await tester.tap(find.widgetWithText(FilledButton, 'Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('4'), findsWidgets);
    });

    testWidgets('should trigger logout when logout button is pressed', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [];
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final logoutButton = find.widgetWithText(OutlinedButton, 'Çıkış Yap');
      await tester.ensureVisible(logoutButton);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(fakeController.logoutCalls, 1);
    });

    testWidgets('should not overflow on small screens (320x568)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeRepo.listResult = dummyAppointments;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
