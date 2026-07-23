import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';

void main() {
  group('TokenResponse Model Tests', () {
    const validJson = {
      'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
      'token_type': 'bearer',
      'expires_in': 1800,
    };

    test('should parse correctly from valid JSON', () {
      final response = TokenResponse.fromJson(validJson);
      expect(response.accessToken, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
      expect(response.tokenType, 'bearer');
      expect(response.expiresIn, 1800);
    });

    test(
      'should throw FormatException when JSON is missing required fields',
      () {
        const missingFieldJson = {
          'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
          'token_type': 'bearer',
        };
        expect(
          () => TokenResponse.fromJson(missingFieldJson),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('should throw FormatException when JSON has incorrect types', () {
      const incorrectTypeJson = {
        'access_token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
        'token_type': 'bearer',
        'expires_in': '1800', // Should be int
      };
      expect(
        () => TokenResponse.fromJson(incorrectTypeJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('should mask token in toString() output', () {
      final response = TokenResponse.fromJson(validJson);
      final str = response.toString();
      expect(str, contains('accessToken: [MASKED]'));
      expect(str, isNot(contains('eyJhbGci')));
    });
  });
}
