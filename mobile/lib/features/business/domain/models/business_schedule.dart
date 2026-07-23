class BusinessSchedule {
  final int dayOfWeek;
  final String? startTime;
  final String? endTime;
  final bool isClosed;

  const BusinessSchedule({
    required this.dayOfWeek,
    this.startTime,
    this.endTime,
    required this.isClosed,
  });

  factory BusinessSchedule.fromJson(Map<String, dynamic> json) {
    final dayOfWeek = json['day_of_week'] as int?;
    final isClosed = json['is_closed'] as bool?;

    if (dayOfWeek == null) {
      throw const FormatException('Missing required field: day_of_week');
    }
    if (isClosed == null) {
      throw const FormatException('Missing required field: is_closed');
    }

    return BusinessSchedule(
      dayOfWeek: dayOfWeek,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      isClosed: isClosed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_closed': isClosed,
    };
  }

  BusinessSchedule copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isClosed,
  }) {
    return BusinessSchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessSchedule &&
        other.dayOfWeek == dayOfWeek &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.isClosed == isClosed;
  }

  @override
  int get hashCode => Object.hash(dayOfWeek, startTime, endTime, isClosed);
}
