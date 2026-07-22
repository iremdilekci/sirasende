class AppointmentDraft {
  final String businessSlug;
  final String businessName;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String customerName;
  final String customerPhone;
  final String? customerNote;

  const AppointmentDraft({
    required this.businessSlug,
    required this.businessName,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.customerName,
    required this.customerPhone,
    this.customerNote,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentDraft &&
        other.businessSlug == businessSlug &&
        other.businessName == businessName &&
        other.appointmentDate == appointmentDate &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.customerName == customerName &&
        other.customerPhone == customerPhone &&
        other.customerNote == customerNote;
  }

  @override
  int get hashCode => Object.hash(
    businessSlug,
    businessName,
    appointmentDate,
    startTime,
    endTime,
    customerName,
    customerPhone,
    customerNote,
  );
}
