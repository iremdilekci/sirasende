import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';

class AppointmentCreateRequest {
  final String customerName;
  final String customerPhone;
  final String appointmentDate;
  final String startTime;
  final String? customerNote;

  const AppointmentCreateRequest({
    required this.customerName,
    required this.customerPhone,
    required this.appointmentDate,
    required this.startTime,
    this.customerNote,
  });

  factory AppointmentCreateRequest.fromDraft(AppointmentDraft draft) {
    return AppointmentCreateRequest(
      customerName: draft.customerName,
      customerPhone: draft.customerPhone,
      appointmentDate: draft.appointmentDate,
      startTime: draft.startTime,
      customerNote: draft.customerNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'appointment_date': appointmentDate,
      'start_time': startTime,
      if (customerNote != null) 'customer_note': customerNote,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentCreateRequest &&
        other.customerName == customerName &&
        other.customerPhone == customerPhone &&
        other.appointmentDate == appointmentDate &&
        other.startTime == startTime &&
        other.customerNote == customerNote;
  }

  @override
  int get hashCode => Object.hash(
    customerName,
    customerPhone,
    appointmentDate,
    startTime,
    customerNote,
  );
}
