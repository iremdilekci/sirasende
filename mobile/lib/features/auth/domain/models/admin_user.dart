import 'package:flutter/foundation.dart';

@immutable
class AdminUser {
  final String id;
  final String businessId;
  final String username;
  final String email;
  final bool isActive;

  const AdminUser({
    required this.id,
    required this.businessId,
    required this.username,
    required this.email,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('id') ||
        !json.containsKey('business_id') ||
        !json.containsKey('username') ||
        !json.containsKey('email') ||
        !json.containsKey('is_active')) {
      throw const FormatException('Missing required fields in AdminUser JSON');
    }
    return AdminUser(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'username': username,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminUser &&
        other.id == id &&
        other.businessId == businessId &&
        other.username == username &&
        other.email == email &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, businessId, username, email, isActive);

  @override
  String toString() {
    // Avoid leaking email/username if deemed sensitive, but typical for toString.
    // We mask them to be completely safe.
    return 'AdminUser(id: $id, businessId: $businessId, username: ***, email: ***, isActive: $isActive)';
  }
}
