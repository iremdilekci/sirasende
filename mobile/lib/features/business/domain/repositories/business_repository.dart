import 'package:sirasende_mobile/features/business/domain/models/business.dart';

abstract interface class BusinessRepository {
  Future<List<Business>> getBusinesses();
  Future<Business> getBusinessBySlug(String slug);
}
