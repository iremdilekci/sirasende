import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';

void main() {
  group('BusinessSchedule Model Tests', () {
    test('should parse open day schedule successfully', () {
      final json = {
        'day_of_week': 1,
        'start_time': '09:00:00',
        'end_time': '18:00:00',
        'is_closed': false,
      };

      final schedule = BusinessSchedule.fromJson(json);

      expect(schedule.dayOfWeek, 1);
      expect(schedule.startTime, '09:00:00');
      expect(schedule.endTime, '18:00:00');
      expect(schedule.isClosed, isFalse);
    });

    test('should parse closed day schedule with null times successfully', () {
      final json = {
        'day_of_week': 0,
        'start_time': null,
        'end_time': null,
        'is_closed': true,
      };

      final schedule = BusinessSchedule.fromJson(json);

      expect(schedule.dayOfWeek, 0);
      expect(schedule.startTime, isNull);
      expect(schedule.endTime, isNull);
      expect(schedule.isClosed, isTrue);
    });

    test('should serialize to correct json and format', () {
      const schedule = BusinessSchedule(
        dayOfWeek: 2,
        startTime: '10:00:00',
        endTime: '17:00:00',
        isClosed: false,
      );

      final json = schedule.toJson();

      expect(json['day_of_week'], 2);
      expect(json['start_time'], '10:00:00');
      expect(json['end_time'], '17:00:00');
      expect(json['is_closed'], isFalse);
    });
  });
}
