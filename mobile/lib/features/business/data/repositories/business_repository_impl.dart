import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';

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
}
