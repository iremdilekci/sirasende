import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';

void main() {
  group('AdminUser Model Tests', () {
    const validJson = {
      'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
      'username': 'berber_admin',
      'email': 'admin@berber.com',
      'is_active': true,
    };

    test('should parse correctly from valid JSON', () {
      final user = AdminUser.fromJson(validJson);
      expect(user.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(user.businessId, 'f5cc002d-3ed5-478e-3614-58f86d80b65c');
      expect(user.username, 'berber_admin');
      expect(user.email, 'admin@berber.com');
      expect(user.isActive, true);
    });

    test(
      'should throw FormatException when JSON is missing required fields',
      () {
        const missingFieldJson = {
          'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
          'username': 'berber_admin',
          'email': 'admin@berber.com',
          'is_active': true,
        };
        expect(
          () => AdminUser.fromJson(missingFieldJson),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('should support equality comparison and hashCode', () {
      final u1 = AdminUser.fromJson(validJson);
      final u2 = AdminUser.fromJson(validJson);
      expect(u1, u2);
      expect(u1.hashCode, u2.hashCode);
    });

    test('should mask sensitive details in toString() implementation', () {
      final user = AdminUser.fromJson(validJson);
      final str = user.toString();
      expect(str, contains('username: ***'));
      expect(str, contains('email: ***'));
      expect(str, isNot(contains('berber_admin')));
      expect(str, isNot(contains('admin@berber.com')));
    });
  });
}
