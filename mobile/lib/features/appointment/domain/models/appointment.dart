class Appointment {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final String? customerNote;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String status;
  final String createdAt;
  final String updatedAt;

  const Appointment({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.customerPhone,
    this.customerNote,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['business_id'] is! String ||
        json['customer_name'] is! String ||
        json['customer_phone'] is! String ||
        json['appointment_date'] is! String ||
        json['start_time'] is! String ||
        json['end_time'] is! String ||
        json['status'] is! String ||
        json['created_at'] is! String ||
        json['updated_at'] is! String) {
      throw const FormatException('Zorunlu alan eksik veya geçersiz tipte.');
    }

    return Appointment(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      customerNote: json['customer_note'] as String?,
      appointmentDate: json['appointment_date'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Appointment &&
        other.id == id &&
        other.businessId == businessId &&
        other.customerName == customerName &&
        other.customerPhone == customerPhone &&
        other.customerNote == customerNote &&
        other.appointmentDate == appointmentDate &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessId,
    customerName,
    customerPhone,
    customerNote,
    appointmentDate,
    startTime,
    endTime,
    status,
    createdAt,
    updatedAt,
  );
}
