import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/dio_provider.dart';
import 'package:sirasende_mobile/features/business/data/datasources/google_calendar_remote_data_source.dart';
import 'package:sirasende_mobile/features/business/data/repositories/google_calendar_repository_impl.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';
import 'package:sirasende_mobile/features/business/domain/repositories/google_calendar_repository.dart';

final googleCalendarRemoteDataSourceProvider = Provider<GoogleCalendarRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return GoogleCalendarRemoteDataSource(dio);
});

final googleCalendarRepositoryProvider = Provider<GoogleCalendarRepository>((ref) {
  final remoteDataSource = ref.watch(googleCalendarRemoteDataSourceProvider);
  return GoogleCalendarRepositoryImpl(remoteDataSource);
});

final googleCalendarStatusProvider = FutureProvider.autoDispose<GoogleCalendarConnectionStatus>((ref) {
  return ref.watch(googleCalendarRepositoryProvider).getConnectionStatus();
});

class GoogleCalendarController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<String?> connect({
    required void Function(String message) onError,
  }) async {
    state = const AsyncValue.loading();
    String? authUrl;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(googleCalendarRepositoryProvider);
      final result = await repo.getConnectUrl();
      authUrl = result.authorizationUrl;
    });

    if (state.hasError) {
      final error = state.error;
      final message = error is AppException
          ? error.message
          : 'Google bağlantı sayfası alınamadı. Lütfen tekrar deneyin.';
      onError(message);
    }
    return authUrl;
  }

  Future<void> disconnect({
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(googleCalendarRepositoryProvider);
      await repo.disconnect();
      ref.invalidate(googleCalendarStatusProvider);
      onSuccess();
    });

    if (state.hasError) {
      final error = state.error;
      final message = error is AppException
          ? error.message
          : 'Google bağlantısı kaldırılamadı. Lütfen tekrar deneyin.';
      onError(message);
    }
  }
}

final googleCalendarControllerProvider =
    AsyncNotifierProvider.autoDispose<GoogleCalendarController, void>(
  GoogleCalendarController.new,
);
