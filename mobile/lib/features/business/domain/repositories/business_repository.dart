import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';

import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';

abstract interface class BusinessRepository {
  Future<List<Business>> getBusinesses();
  Future<Business> getBusinessBySlug(String slug);
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  });
  Future<Business> getAdminBusiness();
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  });
}
