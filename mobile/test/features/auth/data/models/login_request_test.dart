import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';

void main() {
  group('LoginRequest Model Tests', () {
    test('should serialize correctly to JSON', () {
      const request = LoginRequest(
        identifier: ' admin@example.com ',
        password: ' password123 ',
      );
      final json = request.toJson();
      expect(json['identifier'], ' admin@example.com ');
      // Password must not be modified or trimmed on client-side!
      expect(json['password'], ' password123 ');
    });

    test('should mask password in toString() output', () {
      const request = LoginRequest(
        identifier: 'admin_user',
        password: 'secretpassword',
      );
      final str = request.toString();
      expect(str, contains('identifier: admin_user'));
      expect(str, contains('password: [MASKED]'));
      expect(str, isNot(contains('secretpassword')));
    });
  });
}
