import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_appointments_screen.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  List<Appointment> listResult = [];
  Object? error;
  int listCallCount = 0;
  String? lastDate;
  String? lastStatus;

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
    lastStatus = status;
    if (error != null) throw error!;
    return listResult;
  }
}

void main() {
  group('AdminAppointmentsScreen Widget Tests', () {
    late FakeAppointmentRepository fakeRepo;

    final dummyAppointment = const Appointment(
      id: 'a1b2',
      businessId: 'b1',
      customerName: 'Ahmet Can',
      customerPhone: '05554443322',
      customerNote: 'Saç kesimi',
      appointmentDate: '2026-07-22',
      startTime: '09:00',
      endTime: '09:30',
      status: 'pending',
      createdAt: '2026-07-22T08:00:00Z',
      updatedAt: '2026-07-22T08:00:00Z',
    );

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const MaterialApp(home: AdminAppointmentsScreen()),
      );
    }

    testWidgets('should render progress indicator during initial load', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [];
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display appointment list details on success', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [dummyAppointment];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Ahmet Can'), findsOneWidget);
      expect(find.text('Beklemede'), findsWidgets); // Status badge
      expect(find.text('2026-07-22'), findsOneWidget);
      expect(find.text('09:00 - 09:30'), findsOneWidget);
      expect(find.text('Not:'), findsOneWidget);
      expect(find.text('Saç kesimi'), findsOneWidget);
    });

    testWidgets('should display empty message state when list is empty', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Henüz randevu bulunmuyor'), findsOneWidget);
      expect(
        find.text(
          'Seçilen filtrelere uygun gelen bir randevu bulunmamaktadır.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should display retry screen when fetch fails', (
      WidgetTester tester,
    ) async {
      fakeRepo.error = const AppException(
        message: 'Oturum doğrulanırken bir hata oluştu.',
        code: 'UNAUTHORIZED',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Randevular Yüklenemedi'), findsOneWidget);
      expect(
        find.text('Oturum doğrulanırken bir hata oluştu.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Tekrar Dene'), findsOneWidget);

      // Tap Retry
      fakeRepo.error = null;
      fakeRepo.listResult = [dummyAppointment];
      await tester.tap(find.widgetWithText(FilledButton, 'Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmet Can'), findsOneWidget);
    });

    testWidgets('should trigger filters correctly', (
      WidgetTester tester,
    ) async {
      fakeRepo.listResult = [dummyAppointment];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Change status filter
      await tester.tap(find.text('Tüm Durumlar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onaylandı').last);
      await tester.pumpAndSettle();

      expect(fakeRepo.lastStatus, 'confirmed');

      // Clear button should clear selection
      await tester.tap(find.text('Temizle'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastStatus, isNull);
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

      fakeRepo.listResult = [dummyAppointment];
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
