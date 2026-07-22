import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';

abstract class AppointmentRepository {
  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  });
}
