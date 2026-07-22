import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';

void main() {
  group('AppointmentCreateRequest Tests', () {
    test('should map from AppointmentDraft correctly', () {
      const draft = AppointmentDraft(
        businessSlug: 'berber-ahmet',
        businessName: 'Berber Ahmet',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        endTime: '09:30',
        customerName: 'Ayse Can',
        customerPhone: '05554443322',
        customerNote: 'Sac kesimi',
      );

      final request = AppointmentCreateRequest.fromDraft(draft);
      expect(request.customerName, 'Ayse Can');
      expect(request.customerPhone, '05554443322');
      expect(request.appointmentDate, '2026-07-22');
      expect(request.startTime, '09:00');
      expect(request.customerNote, 'Sac kesimi');
    });

    test(
      'should serialize to JSON with correct key mappings and exclude null note',
      () {
        const request = AppointmentCreateRequest(
          customerName: 'Ayse Can',
          customerPhone: '05554443322',
          appointmentDate: '2026-07-22',
          startTime: '09:00',
          customerNote: null,
        );

        final json = request.toJson();
        expect(json['customer_name'], 'Ayse Can');
        expect(json['customer_phone'], '05554443322');
        expect(json['appointment_date'], '2026-07-22');
        expect(json['start_time'], '09:00');
        expect(json.containsKey('customer_note'), isFalse);
        expect(json.containsKey('end_time'), isFalse);
        expect(json.containsKey('business_slug'), isFalse);
      },
    );

    test('should serialize to JSON with note included if present', () {
      const request = AppointmentCreateRequest(
        customerName: 'Ayse Can',
        customerPhone: '05554443322',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        customerNote: 'Sac kesimi olsun',
      );

      final json = request.toJson();
      expect(json['customer_note'], 'Sac kesimi olsun');
    });
  });
}
