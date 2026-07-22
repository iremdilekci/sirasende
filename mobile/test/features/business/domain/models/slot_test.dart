import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';

void main() {
  group('Slot Model Tests', () {
    test('should parse valid JSON successfully', () {
      final json = {
        'start_time': '09:00',
        'end_time': '09:30',
        'available': true,
        'reason': null,
      };

      final slot = Slot.fromJson(json);

      expect(slot.startTime, '09:00');
      expect(slot.endTime, '09:30');
      expect(slot.available, isTrue);
      expect(slot.reason, isNull);
    });

    test('should parse JSON with non-null reason successfully', () {
      final json = {
        'start_time': '09:30',
        'end_time': '10:00',
        'available': false,
        'reason': 'booked',
      };

      final slot = Slot.fromJson(json);

      expect(slot.startTime, '09:30');
      expect(slot.endTime, '10:00');
      expect(slot.available, isFalse);
      expect(slot.reason, 'booked');
    });

    test('should throw FormatException when start_time is missing', () {
      final json = {'end_time': '09:30', 'available': true};

      expect(() => Slot.fromJson(json), throwsFormatException);
    });

    test('should throw FormatException when start_time has wrong type', () {
      final json = {'start_time': 900, 'end_time': '09:30', 'available': true};

      expect(() => Slot.fromJson(json), throwsFormatException);
    });

    test('should throw FormatException when available is missing', () {
      final json = {'start_time': '09:00', 'end_time': '09:30'};

      expect(() => Slot.fromJson(json), throwsFormatException);
    });

    test('should verify equality and hashCode overrides', () {
      const slot1 = Slot(
        startTime: '09:00',
        endTime: '09:30',
        available: true,
        reason: null,
      );

      const slot2 = Slot(
        startTime: '09:00',
        endTime: '09:30',
        available: true,
        reason: null,
      );

      const slot3 = Slot(
        startTime: '09:00',
        endTime: '09:30',
        available: false,
        reason: 'booked',
      );

      expect(slot1, slot2);
      expect(slot1.hashCode, slot2.hashCode);
      expect(slot1, isNot(slot3));
    });
  });
}
