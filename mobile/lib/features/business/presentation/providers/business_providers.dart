import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/network/dio_provider.dart';
import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/data/repositories/business_repository_impl.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/business_repository.dart';

final businessRemoteDataSourceProvider = Provider<BusinessRemoteDataSource>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  return BusinessRemoteDataSource(dio);
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  final remoteDataSource = ref.watch(businessRemoteDataSourceProvider);
  return BusinessRepositoryImpl(remoteDataSource);
});

/// Future provider to fetch the list of active businesses.
/// Uses autoDispose so that the list is refetched next time the screen is opened.
final businessesProvider = FutureProvider.autoDispose<List<Business>>((ref) {
  return ref.watch(businessRepositoryProvider).getBusinesses();
});

/// Family Future provider to fetch the details of a specific business by slug.
/// Uses autoDispose to avoid caching outdated detail states when navigating away.
final businessDetailProvider = FutureProvider.autoDispose
    .family<Business, String>((ref, slug) {
      return ref.watch(businessRepositoryProvider).getBusinessBySlug(slug);
    });
