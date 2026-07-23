import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';

import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final BusinessRemoteDataSource _remoteDataSource;

  BusinessRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Business>> getBusinesses() {
    return _remoteDataSource.fetchBusinesses();
  }

  @override
  Future<Business> getBusinessBySlug(String slug) {
    return _remoteDataSource.fetchBusinessBySlug(slug);
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) {
    return _remoteDataSource.fetchBusinessSlots(slug, date);
  }

  @override
  Future<Business> getAdminBusiness() {
    return _remoteDataSource.fetchAdminBusiness();
  }

  @override
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  }) {
    return _remoteDataSource.updateAdminBusiness(
      name: name,
      description: description,
      phone: phone,
      address: address,
      workingStartTime: workingStartTime,
      workingEndTime: workingEndTime,
      slotDurationMinutes: slotDurationMinutes,
      schedules: schedules,
    );
  }
}
