import 'package:flutter/foundation.dart';

@immutable
class TokenResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('access_token') ||
        !json.containsKey('token_type') ||
        !json.containsKey('expires_in')) {
      throw const FormatException(
        'Missing required fields in TokenResponse JSON',
      );
    }
    final token = json['access_token'];
    final type = json['token_type'];
    final expires = json['expires_in'];

    if (token is! String || type is! String || expires is! int) {
      throw const FormatException('Invalid type format in TokenResponse JSON');
    }

    return TokenResponse(
      accessToken: token,
      tokenType: type,
      expiresIn: expires,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }

  @override
  String toString() {
    return 'TokenResponse(accessToken: [MASKED], tokenType: $tokenType, expiresIn: $expiresIn)';
  }
}
