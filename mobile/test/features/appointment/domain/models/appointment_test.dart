import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';

void main() {
  group('Appointment Model Tests', () {
    final validJson = {
      'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
      'customer_name': 'Ahmet Yilmaz',
      'customer_phone': '05554443322',
      'customer_note': 'Sac kesimi',
      'appointment_date': '2026-07-22',
      'start_time': '09:00',
      'end_time': '09:30',
      'status': 'pending',
      'created_at': '2026-07-22T20:00:00Z',
      'updated_at': '2026-07-22T20:00:00Z',
    };

    test('should parse valid JSON response correctly', () {
      final appointment = Appointment.fromJson(validJson);
      expect(appointment.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(appointment.businessId, 'f5cc002d-3ed5-478e-3614-58f86d80b65c');
      expect(appointment.customerName, 'Ahmet Yilmaz');
      expect(appointment.customerPhone, '05554443322');
      expect(appointment.customerNote, 'Sac kesimi');
      expect(appointment.appointmentDate, '2026-07-22');
      expect(appointment.startTime, '09:00');
      expect(appointment.endTime, '09:30');
      expect(appointment.status, 'pending');
      expect(appointment.createdAt, '2026-07-22T20:00:00Z');
    });

    test('should throw FormatException when a mandatory field is missing', () {
      final invalidJson = Map<String, dynamic>.from(validJson)..remove('id');
      expect(() => Appointment.fromJson(invalidJson), throwsFormatException);
    });

    test(
      'should throw FormatException when a mandatory field has incorrect type',
      () {
        final invalidJson = Map<String, dynamic>.from(validJson)..['id'] = 123;
        expect(() => Appointment.fromJson(invalidJson), throwsFormatException);
      },
    );

    test('should handle null optional note correctly', () {
      final noNoteJson = Map<String, dynamic>.from(validJson)
        ..['customer_note'] = null;
      final appointment = Appointment.fromJson(noNoteJson);
      expect(appointment.customerNote, isNull);
    });

    test('should verify equality and hashCode overrides', () {
      final apt1 = Appointment.fromJson(validJson);
      final apt2 = Appointment.fromJson(validJson);
      final apt3 = Appointment.fromJson(
        Map<String, dynamic>.from(validJson)..['status'] = 'confirmed',
      );

      expect(apt1, apt2);
      expect(apt1.hashCode, apt2.hashCode);
      expect(apt1, isNot(apt3));
    });
  });
}
