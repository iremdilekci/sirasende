import 'package:flutter/foundation.dart';

@immutable
class RegistrationRequest {
  final String username;
  final String email;
  final String password;
  final String businessName;
  final String? phone;
  final String? address;
  final String? description;
  final int slotDurationMinutes;

  const RegistrationRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.businessName,
    this.phone,
    this.address,
    this.description,
    required this.slotDurationMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      'business_name': businessName,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'slot_duration_minutes': slotDurationMinutes,
    };
  }

  @override
  String toString() {
    return 'RegistrationRequest(username: $username, email: $email, businessName: $businessName, phone: $phone, address: $address, description: $description, slotDurationMinutes: $slotDurationMinutes, password: [MASKED])';
  }
}
