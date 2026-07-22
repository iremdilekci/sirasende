class Slot {
  final String startTime;
  final String endTime;
  final bool available;
  final String? reason;

  const Slot({
    required this.startTime,
    required this.endTime,
    required this.available,
    this.reason,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    final startTime = json['start_time'];
    final endTime = json['end_time'];
    final available = json['available'];
    final reason = json['reason'];

    if (startTime == null) {
      throw const FormatException('Missing required field: start_time');
    }
    if (startTime is! String) {
      throw const FormatException('Field start_time must be a String');
    }

    if (endTime == null) {
      throw const FormatException('Missing required field: end_time');
    }
    if (endTime is! String) {
      throw const FormatException('Field end_time must be a String');
    }

    if (available == null) {
      throw const FormatException('Missing required field: available');
    }
    if (available is! bool) {
      throw const FormatException('Field available must be a bool');
    }

    if (reason != null && reason is! String) {
      throw const FormatException('Field reason must be a String');
    }

    return Slot(
      startTime: startTime,
      endTime: endTime,
      available: available,
      reason: reason as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'available': available,
      'reason': reason,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Slot &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.available == available &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(startTime, endTime, available, reason);
}
