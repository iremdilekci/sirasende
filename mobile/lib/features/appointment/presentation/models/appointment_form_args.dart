class AppointmentFormArgs {
  final String businessSlug;
  final String businessName;
  final String date;
  final String startTime;
  final String endTime;

  const AppointmentFormArgs({
    required this.businessSlug,
    required this.businessName,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentFormArgs &&
        other.businessSlug == businessSlug &&
        other.businessName == businessName &&
        other.date == date &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode =>
      Object.hash(businessSlug, businessName, date, startTime, endTime);
}
