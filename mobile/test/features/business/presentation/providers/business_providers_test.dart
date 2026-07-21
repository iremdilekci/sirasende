import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class FakeBusinessRepository implements BusinessRepository {
  List<Business>? businessesResult;
  Business? businessResult;
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
  });
}
