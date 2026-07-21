import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';

void main() {
  group('AppException Tests', () {
    test('should store message correctly', () {
      const exception = AppException(message: 'Something went wrong');
      expect(exception.message, 'Something went wrong');
      expect(exception.code, isNull);
    });

    test('should store optional error code correctly', () {
      const exception = AppException(
        message: 'Access denied',
        code: 'UNAUTHORIZED',
      );
      expect(exception.message, 'Access denied');
      expect(exception.code, 'UNAUTHORIZED');
    });

    test('toString should output clean message without code', () {
      const exception = AppException(message: 'Network error');
      expect(exception.toString(), 'AppException: Network error');
    });

    test('toString should include code when available', () {
      const exception = AppException(
        message: 'Conflict occurred',
        code: 'CONFLICT',
      );
      expect(exception.toString(), 'AppException[CONFLICT]: Conflict occurred');
    });
  });
}
