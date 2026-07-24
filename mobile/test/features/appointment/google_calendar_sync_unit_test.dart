import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_appointments_screen.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';

class FakeSyncAppointmentRepository implements AppointmentRepository {
  Appointment? syncResult;
  Object? syncError;
  int syncCalls = 0;
  String? lastSyncedId;

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
    return [
      Appointment(
        id: 'a1',
        businessId: 'b1',
        customerName: 'Kamil Yılmaz',
        customerPhone: '05553332211',
        appointmentDate: '2026-07-25',
        startTime: '10:00',
        endTime: '10:30',
        status: 'confirmed',
        createdAt: '2026-07-25T08:00:00Z',
        updatedAt: '2026-07-25T08:00:00Z',
        calendarSyncStatus: 'failed',
        calendarEventCreated: false,
        calendarSyncError: 'Connection refused',
      ),
      const Appointment(
        id: 'a2',
        businessId: 'b1',
        customerName: 'Melis Kaya',
        customerPhone: '05554443322',
        appointmentDate: '2026-07-25',
        startTime: '11:00',
        endTime: '11:30',
        status: 'confirmed',
        createdAt: '2026-07-25T08:00:00Z',
        updatedAt: '2026-07-25T08:00:00Z',
        calendarSyncStatus: 'synced',
        calendarEventCreated: true,
      ),
    ];
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
    syncCalls++;
    lastSyncedId = id;
    if (syncError != null) throw syncError!;
    return syncResult ??
        Appointment(
          id: id,
          businessId: 'b1',
          customerName: 'Kamil Yılmaz',
          customerPhone: '05553332211',
          appointmentDate: '2026-07-25',
          startTime: '10:00',
          endTime: '10:30',
          status: 'confirmed',
          createdAt: '2026-07-25T08:00:00Z',
          updatedAt: '2026-07-25T08:00:00Z',
          calendarSyncStatus: 'synced',
          calendarEventCreated: true,
        );
  }
}

void main() {
  group('Google Calendar Sync Domain Model Tests', () {
    test('Appointment fromJson parses sync status fields successfully', () {
      final json = {
        'id': 'app-123',
        'business_id': 'bus-456',
        'customer_name': 'Ahmet Demir',
        'customer_phone': '05321112233',
        'appointment_date': '2026-07-25',
        'start_time': '14:00',
        'end_time': '14:30',
        'status': 'confirmed',
        'created_at': '2026-07-24T12:00:00Z',
        'updated_at': '2026-07-24T12:00:00Z',
        'calendar_sync_status': 'synced',
        'calendar_event_created': true,
        'calendar_sync_error': 'None',
      };

      final appointment = Appointment.fromJson(json);

      expect(appointment.calendarSyncStatus, 'synced');
      expect(appointment.calendarEventCreated, true);
      expect(appointment.calendarSyncError, 'None');
    });

    test(
      'Appointment fromJson fallback/default behavior for backward compatibility',
      () {
        final json = {
          'id': 'app-123',
          'business_id': 'bus-456',
          'customer_name': 'Ahmet Demir',
          'customer_phone': '05321112233',
          'appointment_date': '2026-07-25',
          'start_time': '14:00',
          'end_time': '14:30',
          'status': 'confirmed',
          'created_at': '2026-07-24T12:00:00Z',
          'updated_at': '2026-07-24T12:00:00Z',
        };

        final appointment = Appointment.fromJson(json);

        expect(appointment.calendarSyncStatus, 'not_connected');
        expect(appointment.calendarEventCreated, false);
        expect(appointment.calendarSyncError, isNull);
      },
    );
  });

  group('GoogleCalendarSyncController Provider Tests', () {
    late FakeSyncAppointmentRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeSyncAppointmentRepository();
      container = ProviderContainer(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is AsyncData(null)', () {
      final state = container.read(googleCalendarSyncControllerProvider);
      expect(state, const AsyncValue<void>.data(null));
    });

    test(
      'syncAppointment success updates state and invokes repository',
      () async {
        final controller = container.read(
          googleCalendarSyncControllerProvider.notifier,
        );

        bool successCalled = false;
        String? errorMessage;

        await controller.syncAppointment(
          id: 'a1',
          onSuccess: () => successCalled = true,
          onError: (msg) => errorMessage = msg,
        );

        expect(fakeRepo.syncCalls, 1);
        expect(fakeRepo.lastSyncedId, 'a1');
        expect(successCalled, true);
        expect(errorMessage, isNull);
        expect(
          container.read(googleCalendarSyncControllerProvider),
          const AsyncValue<void>.data(null),
        );
      },
    );

    test(
      'syncAppointment failure maps AppException and notifies user',
      () async {
        fakeRepo.syncError = const AppException(
          message: 'Google yetkilendirme hatası.',
          code: 'AUTH_FAILED',
        );

        final controller = container.read(
          googleCalendarSyncControllerProvider.notifier,
        );

        bool successCalled = false;
        String? errorMessage;

        await controller.syncAppointment(
          id: 'a1',
          onSuccess: () => successCalled = true,
          onError: (msg) => errorMessage = msg,
        );

        expect(fakeRepo.syncCalls, 1);
        expect(successCalled, false);
        expect(errorMessage, 'Google yetkilendirme hatası.');
        expect(
          container.read(googleCalendarSyncControllerProvider).hasError,
          true,
        );
      },
    );
  });

  group('Google Calendar Sync Widget/Screen Integration Tests', () {
    late FakeSyncAppointmentRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeSyncAppointmentRepository();
    });

    Widget makeTestableWidget() {
      return ProviderScope(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const MaterialApp(home: AdminAppointmentsScreen()),
      );
    }

    testWidgets('Displays Google Calendar status indicators and retry button', (
      tester,
    ) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      // The status 'failed' should display 'Senkronizasyon başarısız' and a retry button 'Tekrar Dene'
      expect(find.text('Senkronizasyon başarısız'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);

      // The status 'synced' should display 'Google Takvim\'e eklendi'
      expect(find.text('Google Takvim\'e eklendi'), findsOneWidget);
    });

    testWidgets('Tapping Tekrar Dene invokes sync process', (tester) async {
      await tester.pumpWidget(makeTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();

      expect(fakeRepo.syncCalls, 1);
      expect(fakeRepo.lastSyncedId, 'a1');
    });
  });
}
