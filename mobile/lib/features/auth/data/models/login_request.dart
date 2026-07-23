import 'package:flutter/foundation.dart';

@immutable
class LoginRequest {
  final String identifier;
  final String password;

  const LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() {
    return {'identifier': identifier, 'password': password};
  }

  @override
  String toString() {
    // Avoid leaking password/credentials in logs or debug dumps.
    return 'LoginRequest(identifier: $identifier, password: [MASKED])';
  }
}
