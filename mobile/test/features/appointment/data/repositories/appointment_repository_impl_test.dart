import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/data/repositories/appointment_repository_impl.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/data/datasources/appointment_remote_data_source.dart';

class FakeAppointmentRemoteDataSource implements AppointmentRemoteDataSource {
  Appointment? result;
  Object? error;
  int callCount = 0;
  String? lastSlug;
  AppointmentCreateRequest? lastRequest;

  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    callCount++;
    lastSlug = businessSlug;
    lastRequest = request;
    if (error != null) throw error!;
    return result!;
  }
}

void main() {
  group('AppointmentRepositoryImpl Tests', () {
    late FakeAppointmentRemoteDataSource fakeRemoteDS;
    late AppointmentRepositoryImpl repository;

    setUp(() {
      fakeRemoteDS = FakeAppointmentRemoteDataSource();
      repository = AppointmentRepositoryImpl(fakeRemoteDS);
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

    test(
      'should delegate createAppointment to remote data source and return value on success',
      () async {
        fakeRemoteDS.result = dummyAppointment;

        final result = await repository.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        );

        expect(result, dummyAppointment);
        expect(fakeRemoteDS.callCount, 1);
        expect(fakeRemoteDS.lastSlug, 'berber-ahmet');
        expect(fakeRemoteDS.lastRequest, dummyRequest);
      },
    );

    test('should propagate exceptions thrown by remote data source', () async {
      fakeRemoteDS.error = const AppException(
        message: 'Conflict error occurred',
        code: 'CONFLICT',
      );

      expect(
        () => repository.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'CONFLICT')),
      );
    });
  });
}
