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

    test('should start in idle state', () {
      final state = container.read(appointmentControllerProvider);
      expect(state, const AsyncValue<Appointment?>.data(null));
    });

    test(
      'should progress to success state and call onSuccess callback',
      () async {
        fakeRepo.result = dummyAppointment;

        Appointment? callbackResult;
        final future = container
            .read(appointmentControllerProvider.notifier)
            .bookAppointment(
              businessSlug: 'berber-ahmet',
              request: dummyRequest,
              onSuccess: (apt) {
                callbackResult = apt;
              },
            );

        // Check intermediate loading state
        expect(container.read(appointmentControllerProvider).isLoading, isTrue);

        await future;

        expect(
          container.read(appointmentControllerProvider).value,
          dummyAppointment,
        );
        expect(callbackResult, dummyAppointment);
        expect(fakeRepo.callCount, 1);
      },
    );

    test('should progress to error state when repository throws', () async {
      fakeRepo.error = const AppException(
        message: 'Conflict',
        code: 'CONFLICT',
      );

      await container
          .read(appointmentControllerProvider.notifier)
          .bookAppointment(businessSlug: 'berber-ahmet', request: dummyRequest);

      final state = container.read(appointmentControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as AppException).code, 'CONFLICT');
      expect(fakeRepo.callCount, 1);
    });

    test('should prevent double submission during loading state', () async {
      fakeRepo.result = dummyAppointment;

      // Start first submission
      final f1 = container
          .read(appointmentControllerProvider.notifier)
          .bookAppointment(businessSlug: 'berber-ahmet', request: dummyRequest);

      // Attempt second submission immediately
      final f2 = container
          .read(appointmentControllerProvider.notifier)
          .bookAppointment(businessSlug: 'berber-ahmet', request: dummyRequest);

      await f1;
      await f2;

      expect(fakeRepo.callCount, 1); // Only called once!
    });
  });
}
