import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/data/repositories/business_repository_impl.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';

class FakeRemoteDataSource extends BusinessRemoteDataSource {
  List<Business>? businessesResult;
  Business? businessResult;
  Object? error;

  FakeRemoteDataSource() : super(Dio());

  @override
  Future<List<Business>> fetchBusinesses() async {
    if (error != null) throw error!;
    return businessesResult ?? [];
  }

  @override
  Future<Business> fetchBusinessBySlug(String slug) async {
    if (error != null) throw error!;
    return businessResult!;
  }
}

void main() {
  group('BusinessRepositoryImpl Tests', () {
    late FakeRemoteDataSource fakeDataSource;
    late BusinessRepositoryImpl repository;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Test',
      slug: 'test',
      slotDurationMinutes: 30,
      isActive: true,
    );

    setUp(() {
      fakeDataSource = FakeRemoteDataSource();
      repository = BusinessRepositoryImpl(fakeDataSource);
    });

    test('getBusinesses should return list from datasource', () async {
      fakeDataSource.businessesResult = [dummyBusiness];
      final result = await repository.getBusinesses();
      expect(result.length, 1);
      expect(result[0].name, 'Test');
    });

    test('getBusinessBySlug should return detail from datasource', () async {
      fakeDataSource.businessResult = dummyBusiness;
      final result = await repository.getBusinessBySlug('test');
      expect(result.name, 'Test');
    });

    test('getBusinesses should propagate exceptions from datasource', () async {
      fakeDataSource.error = Exception('Network error');
      expect(() => repository.getBusinesses(), throwsException);
    });
  });
}
