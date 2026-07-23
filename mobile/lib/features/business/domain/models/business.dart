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
    };
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
        other.updatedAt == updatedAt;
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
    );
  }
}
