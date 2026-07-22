import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';

void main() {
  group('AppointmentDraft Model Tests', () {
    test('should verify equality and hashCode overrides', () {
      const draft1 = AppointmentDraft(
        businessSlug: 'berber-ahmet',
        businessName: 'Berber Ahmet',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        endTime: '09:30',
        customerName: 'Ahmet Can',
        customerPhone: '+905555555555',
        customerNote: 'Sakal traşı',
      );

      const draft2 = AppointmentDraft(
        businessSlug: 'berber-ahmet',
        businessName: 'Berber Ahmet',
        appointmentDate: '2026-07-22',
        startTime: '09:00',
        endTime: '09:30',
        customerName: 'Ahmet Can',
        customerPhone: '+905555555555',
        customerNote: 'Sakal traşı',
      );

      const draft3 = AppointmentDraft(
        businessSlug: 'berber-ahmet',
        businessName: 'Berber Ahmet',
        appointmentDate: '2026-07-22',
        startTime: '09:30',
        endTime: '10:00',
        customerName: 'Ahmet Can',
        customerPhone: '+905555555555',
        customerNote: 'Sakal traşı',
      );

      expect(draft1, draft2);
      expect(draft1.hashCode, draft2.hashCode);
      expect(draft1, isNot(draft3));
    });
  });
}
