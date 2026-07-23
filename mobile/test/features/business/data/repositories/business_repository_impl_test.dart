import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/data/repositories/business_repository_impl.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';

class FakeRemoteDataSource extends BusinessRemoteDataSource {
  List<Business>? businessesResult;
  Business? businessResult;
  List<Slot>? slotsResult;
  String? lastSlug;
  String? lastDate;
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

  @override
  Future<List<Slot>> fetchBusinessSlots(String slug, String date) async {
    lastSlug = slug;
    lastDate = date;
    if (error != null) throw error!;
    return slotsResult ?? [];
  }

  @override
  Future<Business> fetchAdminBusiness() async {
    if (error != null) throw error!;
    return businessResult!;
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
  }) async {
    if (error != null) throw error!;
    return Business(
      id: businessResult!.id,
      name: name,
      slug: businessResult!.slug,
      description: description,
      phone: phone,
      address: address,
      workingStartTime: workingStartTime,
      workingEndTime: workingEndTime,
      slotDurationMinutes:
          slotDurationMinutes ?? businessResult!.slotDurationMinutes,
      isActive: businessResult!.isActive,
    );
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

    test('getBusinessSlots should return list from datasource', () async {
      final dummySlot = const Slot(
        startTime: '09:00',
        endTime: '09:30',
        available: true,
      );
      fakeDataSource.slotsResult = [dummySlot];

      final result = await repository.getBusinessSlots(
        slug: 'test-slug',
        date: '2026-07-22',
      );

      expect(fakeDataSource.lastSlug, 'test-slug');
      expect(fakeDataSource.lastDate, '2026-07-22');
      expect(result.length, 1);
      expect(result[0].startTime, '09:00');
    });

    test(
      'getBusinessSlots should propagate exceptions from datasource',
      () async {
        fakeDataSource.error = Exception('Slot fetch error');
        expect(
          () => repository.getBusinessSlots(
            slug: 'test-slug',
            date: '2026-07-22',
          ),
          throwsException,
        );
      },
    );

    test('getAdminBusiness should delegate to datasource', () async {
      fakeDataSource.businessResult = const Business(
        id: '1',
        name: 'Test',
        slug: 'test',
        description: 'Desc',
        slotDurationMinutes: 30,
        isActive: true,
      );
      final result = await repository.getAdminBusiness();
      expect(result.id, '1');
      expect(result.description, 'Desc');
    });

    test(
      'updateAdminBusiness should delegate to datasource and return updated business',
      () async {
        fakeDataSource.businessResult = const Business(
          id: '1',
          name: 'Test',
          slug: 'test',
          slotDurationMinutes: 30,
          isActive: true,
        );
        final result = await repository.updateAdminBusiness(
          name: 'Updated Name',
          description: 'New Desc',
          phone: '+905550009988',
          address: 'New Address',
          workingStartTime: '08:30',
          workingEndTime: '19:30',
          slotDurationMinutes: 45,
        );

        expect(result.name, 'Updated Name');
        expect(result.description, 'New Desc');
        expect(result.phone, '+905550009988');
        expect(result.address, 'New Address');
        expect(result.workingStartTime, '08:30');
        expect(result.workingEndTime, '19:30');
        expect(result.slotDurationMinutes, 45);
      },
    );
  });
}
