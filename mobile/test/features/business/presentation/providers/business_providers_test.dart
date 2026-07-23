import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business>? businessesResult;
  Business? businessResult;
  List<Slot>? slotsResult;
  String? lastSlug;
  String? lastDate;
  Object? error;

  @override
  Future<List<Business>> getBusinesses() async {
    if (error != null) throw error!;
    return businessesResult ?? [];
  }

  @override
  Future<Business> getBusinessBySlug(String slug) async {
    if (error != null) throw error!;
    return businessResult!;
  }

  @override
  Future<List<Slot>> getBusinessSlots({
    required String slug,
    required String date,
  }) async {
    lastSlug = slug;
    lastDate = date;
    if (error != null) throw error!;
    return slotsResult ?? [];
  }

  @override
  Future<Business> getAdminBusiness() => throw UnimplementedError();

  @override
  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
  }) => throw UnimplementedError();
}

void main() {
  group('Business Providers Tests', () {
    late FakeBusinessRepository fakeRepo;
    late ProviderContainer container;

    final dummyBusiness = const Business(
      id: '1',
      name: 'Test Business',
      slug: 'test-business',
      slotDurationMinutes: 30,
      isActive: true,
    );

    setUp(() {
      fakeRepo = FakeBusinessRepository();
      container = ProviderContainer(
        overrides: [businessRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('businessesProvider should resolve list successfully', () async {
      fakeRepo.businessesResult = [dummyBusiness];

      // Read future and wait
      final result = await container.read(businessesProvider.future);
      expect(result.length, 1);
      expect(result[0].name, 'Test Business');
    });

    test('businessDetailProvider should resolve business by slug', () async {
      fakeRepo.businessResult = dummyBusiness;

      final result = await container.read(
        businessDetailProvider('test-business').future,
      );
      expect(result.name, 'Test Business');
      expect(result.slug, 'test-business');
    });

    test(
      'businessesProvider should return AsyncError when repository fails',
      () async {
        fakeRepo.error = Exception('DB error');

        // Listen to keep the provider alive during async execution
        final sub = container.listen(businessesProvider, (prev, next) {});

        // Wait a short time for the async call to complete
        await Future.delayed(const Duration(milliseconds: 10));

        final state = container.read(businessesProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<Exception>());

        sub.close();
      },
    );

    test('BusinessSlotsParams equality and hashCode overrides', () {
      const params1 = BusinessSlotsParams(slug: 'slug', date: '2026-07-22');
      const params2 = BusinessSlotsParams(slug: 'slug', date: '2026-07-22');
      const params3 = BusinessSlotsParams(slug: 'slug2', date: '2026-07-22');

      expect(params1, params2);
      expect(params1.hashCode, params2.hashCode);
      expect(params1, isNot(params3));
    });

    test('businessSlotsProvider resolves slots list successfully', () async {
      final dummySlot = const Slot(
        startTime: '09:00',
        endTime: '09:30',
        available: true,
      );
      fakeRepo.slotsResult = [dummySlot];

      final params = const BusinessSlotsParams(
        slug: 'test-slug',
        date: '2026-07-22',
      );
      final result = await container.read(businessSlotsProvider(params).future);

      expect(fakeRepo.lastSlug, 'test-slug');
      expect(fakeRepo.lastDate, '2026-07-22');
      expect(result.length, 1);
      expect(result[0].startTime, '09:00');
    });

    test(
      'businessSlotsProvider returns AsyncError when slots fetch fails',
      () async {
        fakeRepo.error = Exception('Slots error');
        final params = const BusinessSlotsParams(
          slug: 'test-slug',
          date: '2026-07-22',
        );

        final sub = container.listen(
          businessSlotsProvider(params),
          (prev, next) {},
        );
        await Future.delayed(const Duration(milliseconds: 10));

        final state = container.read(businessSlotsProvider(params));
        expect(state.hasError, isTrue);
        expect(state.error, isA<Exception>());

        sub.close();
      },
    );

    test(
      'businessSlotsProvider triggers refetch after invalidate call',
      () async {
        final dummySlot1 = const Slot(
          startTime: '09:00',
          endTime: '09:30',
          available: true,
        );
        fakeRepo.slotsResult = [dummySlot1];

        final params = const BusinessSlotsParams(
          slug: 'test-slug',
          date: '2026-07-22',
        );

        // First read
        var result = await container.read(businessSlotsProvider(params).future);
        expect(result[0].startTime, '09:00');

        // Update mock results
        final dummySlot2 = const Slot(
          startTime: '10:00',
          endTime: '10:30',
          available: true,
        );
        fakeRepo.slotsResult = [dummySlot2];

        // Invalidate and re-read
        container.invalidate(businessSlotsProvider(params));
        result = await container.read(businessSlotsProvider(params).future);
        expect(result[0].startTime, '10:00');
      },
    );
  });
}
