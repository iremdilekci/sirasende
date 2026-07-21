import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';

void main() {
  group('Business Model Tests', () {
    final listJson = {
      'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
      'name': 'Berber Ahmet',
      'slug': 'berber-ahmet',
      'address': 'Kadikoy, Istanbul',
      'phone': '+905555555555',
      'slot_duration_minutes': 30,
      'is_active': true,
    };

    final detailJson = {
      'id': 'd290f1ee-6c54-4b01-90e6-d701748f0851',
      'name': 'Berber Ahmet',
      'slug': 'berber-ahmet',
      'address': 'Kadikoy, Istanbul',
      'phone': '+905555555555',
      'working_start_time': '09:00:00',
      'working_end_time': '18:00:00',
      'slot_duration_minutes': 30,
      'is_active': true,
      'created_at': '2026-07-12T10:00:00Z',
      'updated_at': '2026-07-12T12:00:00Z',
    };

    test('should parse list item json successfully', () {
      final business = Business.fromJson(listJson);
      expect(business.id, 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(business.name, 'Berber Ahmet');
      expect(business.slug, 'berber-ahmet');
      expect(business.address, 'Kadikoy, Istanbul');
      expect(business.phone, '+905555555555');
      expect(business.slotDurationMinutes, 30);
      expect(business.isActive, isTrue);
      expect(business.workingStartTime, isNull);
      expect(business.createdAt, isNull);
    });

    test('should parse detail json successfully', () {
      final business = Business.fromJson(detailJson);
      expect(business.id, 'd290f1ee-6c54-4b01-90e6-d701748f0851');
      expect(business.workingStartTime, '09:00:00');
      expect(business.workingEndTime, '18:00:00');
      expect(business.createdAt, '2026-07-12T10:00:00Z');
      expect(business.updatedAt, '2026-07-12T12:00:00Z');
    });

    test('should throw FormatException when required id is missing', () {
      final invalidJson = Map<String, dynamic>.from(listJson)..remove('id');
      expect(() => Business.fromJson(invalidJson), throwsFormatException);
    });

    test('should throw FormatException when required name is missing', () {
      final invalidJson = Map<String, dynamic>.from(listJson)..remove('name');
      expect(() => Business.fromJson(invalidJson), throwsFormatException);
    });

    test('should throw FormatException when type is wrong', () {
      final invalidJson = Map<String, dynamic>.from(listJson)
        ..['slot_duration_minutes'] = 'thirty';
      expect(() => Business.fromJson(invalidJson), throwsA(isA<TypeError>()));
    });

    test('should verify equality and hashCode overrides', () {
      final b1 = Business.fromJson(detailJson);
      final b2 = Business.fromJson(detailJson);
      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
    });
  });
}
