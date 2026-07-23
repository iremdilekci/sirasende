import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/dio_provider.dart';
import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/data/repositories/business_repository_impl.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
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

/// Parameter class for businessSlotsProvider family key.
class BusinessSlotsParams {
  final String slug;
  final String date;

  const BusinessSlotsParams({required this.slug, required this.date});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessSlotsParams &&
        other.slug == slug &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(slug, date);
}

/// Family Future provider to fetch business slots for a given date.
final businessSlotsProvider = FutureProvider.autoDispose
    .family<List<Slot>, BusinessSlotsParams>((ref, params) {
      return ref
          .watch(businessRepositoryProvider)
          .getBusinessSlots(slug: params.slug, date: params.date);
    });

final adminBusinessProvider = FutureProvider.autoDispose<Business>((ref) {
  return ref.watch(businessRepositoryProvider).getAdminBusiness();
});

class AdminBusinessUpdateController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updateBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(businessRepositoryProvider);
      await repository.updateAdminBusiness(
        name: name,
        description: description,
        phone: phone,
        address: address,
        workingStartTime: workingStartTime,
        workingEndTime: workingEndTime,
        slotDurationMinutes: slotDurationMinutes,
      );
      ref.invalidate(adminBusinessProvider);
      onSuccess();
    });

    if (state.hasError) {
      final error = state.error;
      final message = error is AppException
          ? error.message
          : 'Bilgiler kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.';
      onError(message);
    }
  }
}

final adminBusinessUpdateControllerProvider =
    AsyncNotifierProvider.autoDispose<AdminBusinessUpdateController, void>(
      AdminBusinessUpdateController.new,
    );
