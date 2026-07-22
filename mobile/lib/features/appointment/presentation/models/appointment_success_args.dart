class AppointmentSuccessArgs {
  final String businessName;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String status;

  const AppointmentSuccessArgs({
    required this.businessName,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentSuccessArgs &&
        other.businessName == businessName &&
        other.appointmentDate == appointmentDate &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(businessName, appointmentDate, startTime, endTime, status);
}
