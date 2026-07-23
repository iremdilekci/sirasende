import 'package:sirasende_mobile/features/appointment/data/datasources/appointment_remote_data_source.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/domain/repositories/appointment_repository.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppointmentRemoteDataSource _remoteDataSource;

  AppointmentRepositoryImpl(this._remoteDataSource);

  @override
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) {
    return _remoteDataSource.createAppointment(
      businessSlug: businessSlug,
      request: request,
    );
  }

  @override
  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  }) {
    return _remoteDataSource.getAdminAppointments(date: date, status: status);
  }
}
