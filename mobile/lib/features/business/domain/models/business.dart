import 'business_schedule.dart';

class Business {
  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? phone;
  final String? description;
  final int slotDurationMinutes;
  final bool isActive;
  final String? workingStartTime;
  final String? workingEndTime;
  final String? createdAt;
  final String? updatedAt;
  final List<BusinessSchedule> schedules;

  const Business({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    this.description,
    required this.slotDurationMinutes,
    required this.isActive,
    this.workingStartTime,
    this.workingEndTime,
    this.createdAt,
    this.updatedAt,
    this.schedules = const [],
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final slug = json['slug'] as String?;
    final slotDurationMinutes = json['slot_duration_minutes'] as int?;
    final isActive = json['is_active'] as bool?;

    if (id == null) {
      throw const FormatException('Missing required field: id');
    }
    if (name == null) {
      throw const FormatException('Missing required field: name');
    }
    if (slug == null) {
      throw const FormatException('Missing required field: slug');
    }
    if (slotDurationMinutes == null) {
      throw const FormatException(
        'Missing required field: slot_duration_minutes',
      );
    }
    if (isActive == null) {
      throw const FormatException('Missing required field: is_active');
    }

    final schedulesJson = json['schedules'] as List<dynamic>?;
    List<BusinessSchedule> parsedSchedules = [];
    if (schedulesJson != null) {
      parsedSchedules = schedulesJson
          .map((item) => BusinessSchedule.fromJson(item as Map<String, dynamic>))
          .toList();
      parsedSchedules.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    }

    return Business(
      id: id,
      name: name,
      slug: slug,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      slotDurationMinutes: slotDurationMinutes,
      isActive: isActive,
      workingStartTime: json['working_start_time'] as String?,
      workingEndTime: json['working_end_time'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      schedules: parsedSchedules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'address': address,
      'phone': phone,
      'description': description,
      'slot_duration_minutes': slotDurationMinutes,
      'is_active': isActive,
      'working_start_time': workingStartTime,
      'working_end_time': workingEndTime,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'schedules': schedules.map((item) => item.toJson()).toList(),
    };
  }

  Business copyWith({
    String? id,
    String? name,
    String? slug,
    String? address,
    String? phone,
    String? description,
    int? slotDurationMinutes,
    bool? isActive,
    String? workingStartTime,
    String? workingEndTime,
    String? createdAt,
    String? updatedAt,
    List<BusinessSchedule>? schedules,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      description: description ?? this.description,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      isActive: isActive ?? this.isActive,
      workingStartTime: workingStartTime ?? this.workingStartTime,
      workingEndTime: workingEndTime ?? this.workingEndTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schedules: schedules ?? this.schedules,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Business &&
        other.id == id &&
        other.name == name &&
        other.slug == slug &&
        other.address == address &&
        other.phone == phone &&
        other.description == description &&
        other.slotDurationMinutes == slotDurationMinutes &&
        other.isActive == isActive &&
        other.workingStartTime == workingStartTime &&
        other.workingEndTime == workingEndTime &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _listEquals(other.schedules, schedules);
  }

  bool _listEquals(List<BusinessSchedule> a, List<BusinessSchedule> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      slug,
      address,
      phone,
      description,
      slotDurationMinutes,
      isActive,
      workingStartTime,
      workingEndTime,
      createdAt,
      updatedAt,
      Object.hashAll(schedules),
    );
  }
}
