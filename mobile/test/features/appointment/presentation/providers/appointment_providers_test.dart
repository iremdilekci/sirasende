import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';

class FakeAppointmentRepository implements AppointmentRepository {
  Appointment? result;
  Object? error;
  int callCount = 0;

  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    callCount++;
    if (error != null) throw error!;
    return result!;
  }

  List<Appointment>? listResult;
  int listCallCount = 0;
  String? lastDate;
  String? lastStatus;

  @override
  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  }) async {
    listCallCount++;
    lastDate = date;
    lastStatus = status;
    if (error != null) throw error!;
    return listResult!;
  }

  int updateCallCount = 0;
  String? lastUpdateId;
  String? lastUpdateStatus;

  @override
  Future<Appointment> updateAppointmentStatus({
    required String id,
    required String status,
  }) async {
    updateCallCount++;
    lastUpdateId = id;
    lastUpdateStatus = status;
    if (error != null) throw error!;
    return result ??
        const Appointment(
          id: 'dummy',
          businessId: 'dummy',
          customerName: 'dummy',
          customerPhone: 'dummy',
          appointmentDate: 'dummy',
          startTime: 'dummy',
          endTime: 'dummy',
          status: 'confirmed',
          createdAt: 'dummy',
          updatedAt: 'dummy',
        );
  }
}

void main() {
  group('AppointmentController Provider Tests', () {
    late FakeAppointmentRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
      container = ProviderContainer(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    const dummyRequest = AppointmentCreateRequest(
      customerName: 'Ahmet Can',
      customerPhone: '05554443322',
      appointmentDate: '2026-07-22',
      startTime: '09:00',
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

    test('should initialize to null state', () {
      final state = container.read(appointmentControllerProvider);
      expect(state, const AsyncValue<Appointment?>.data(null));
    });

    test(
      'should delegate createAppointment to repository and update state to Success',
      () async {
        fakeRepo.result = dummyAppointment;

        final controller = container.read(
          appointmentControllerProvider.notifier,
        );
        await controller.bookAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        );

        final state = container.read(appointmentControllerProvider);
        expect(state, AsyncValue<Appointment?>.data(dummyAppointment));
        expect(fakeRepo.callCount, 1);
      },
    );

    test('should set state to error when bookAppointment fails', () async {
      fakeRepo.error = const AppException(
        message: 'Conflict',
        code: 'CONFLICT',
      );

      final controller = container.read(appointmentControllerProvider.notifier);
      await controller.bookAppointment(
        businessSlug: 'berber-ahmet',
        request: dummyRequest,
      );

      final state = container.read(appointmentControllerProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<AppException>().having((e) => e.code, 'code', 'CONFLICT'),
      );
    });

    test('should prevent double submission during loading state', () async {
      fakeRepo.result = dummyAppointment;

      final controller = container.read(appointmentControllerProvider.notifier);

      // Trigger first submission
      final future1 = controller.bookAppointment(
        businessSlug: 'berber-ahmet',
        request: dummyRequest,
      );

      // Trigger second submission immediately
      final future2 = controller.bookAppointment(
        businessSlug: 'berber-ahmet',
        request: dummyRequest,
      );

      await Future.wait([future1, future2]);

      expect(fakeRepo.callCount, 1);
    });
  });

  group('Admin Appointments Provider Tests', () {
    late FakeAppointmentRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
      container = ProviderContainer(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

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

    test('AdminAppointmentsParams equality and hashCode overrides', () {
      const params1 = AdminAppointmentsParams(
        date: '2026-07-22',
        status: 'pending',
      );
      const params2 = AdminAppointmentsParams(
        date: '2026-07-22',
        status: 'pending',
      );
      const params3 = AdminAppointmentsParams(
        date: '2026-07-23',
        status: 'pending',
      );

      expect(params1, params2);
      expect(params1.hashCode, params2.hashCode);
      expect(params1, isNot(params3));
    });

    test(
      'should resolve admin appointments from repository successfully',
      () async {
        fakeRepo.listResult = [dummyAppointment];
        const params = AdminAppointmentsParams(
          date: '2026-07-22',
          status: 'pending',
        );

        final value = await container.read(
          adminAppointmentsProvider(params).future,
        );

        expect(value, [dummyAppointment]);
        expect(fakeRepo.listCallCount, 1);
        expect(fakeRepo.lastDate, '2026-07-22');
        expect(fakeRepo.lastStatus, 'pending');
      },
    );

    test('should return AsyncError when repository fails', () async {
      fakeRepo.error = const AppException(
        message: 'Unauthorized',
        code: 'UNAUTHORIZED',
      );
      const params = AdminAppointmentsParams(date: '2026-07-22');

      final sub = container.listen(
        adminAppointmentsProvider(params),
        (prev, next) {},
      );

      // Let microtasks run so that the future completes and transitions the provider state
      await pumpEventQueue();

      final state = container.read(adminAppointmentsProvider(params));
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<AppException>().having((err) => err.code, 'code', 'UNAUTHORIZED'),
      );

      sub.close();
    });
  });

  group('AdminAppointmentActionController Tests', () {
    late FakeAppointmentRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAppointmentRepository();
      container = ProviderContainer(
        overrides: [appointmentRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'should invoke repository and success callback on successful update',
      () async {
        bool successCalled = false;
        bool errorCalled = false;

        final controller = container.read(
          adminAppointmentActionControllerProvider.notifier,
        );

        await controller.updateStatus(
          id: 'appointment-1',
          status: 'confirmed',
          onSuccess: () {
            successCalled = true;
          },
          onError: (msg) {
            errorCalled = true;
          },
        );

        expect(successCalled, isTrue);
        expect(errorCalled, isFalse);
        expect(fakeRepo.updateCallCount, 1);
        expect(fakeRepo.lastUpdateId, 'appointment-1');
        expect(fakeRepo.lastUpdateStatus, 'confirmed');
      },
    );

    test('should invoke error callback on update failure', () async {
      bool successCalled = false;
      String? errorMessage;

      fakeRepo.error = const AppException(
        message: 'Completion not allowed before end time',
        code: 'COMPLETION_NOT_ALLOWED',
      );

      final controller = container.read(
        adminAppointmentActionControllerProvider.notifier,
      );

      await controller.updateStatus(
        id: 'appointment-1',
        status: 'completed',
        onSuccess: () {
          successCalled = true;
        },
        onError: (msg) {
          errorMessage = msg;
        },
      );

      expect(successCalled, isFalse);
      expect(errorMessage, 'Completion not allowed before end time');
      expect(fakeRepo.updateCallCount, 1);
    });
  });
}
