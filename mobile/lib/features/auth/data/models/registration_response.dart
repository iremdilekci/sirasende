import 'package:flutter/foundation.dart';

@immutable
class RegistrationResponse {
  final String adminId;
  final String businessId;
  final String username;
  final String email;
  final String businessName;
  final String message;

  const RegistrationResponse({
    required this.adminId,
    required this.businessId,
    required this.username,
    required this.email,
    required this.businessName,
    required this.message,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      adminId: json['admin_id'] as String,
      businessId: json['business_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      businessName: json['business_name'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'business_id': businessId,
      'username': username,
      'email': email,
      'business_name': businessName,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'RegistrationResponse(adminId: $adminId, businessId: $businessId, username: $username, email: $email, businessName: $businessName, message: $message)';
  }
}
