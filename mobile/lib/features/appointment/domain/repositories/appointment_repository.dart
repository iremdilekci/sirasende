import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';

abstract class AppointmentRepository {
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  });

  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  });

  Future<Appointment> updateAppointmentStatus({
    required String id,
    required String status,
  });
}
