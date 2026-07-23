import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/network/dio_provider.dart';
import 'package:sirasende_mobile/core/storage/secure_storage_provider.dart';
import 'package:sirasende_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthController extends AsyncNotifier<AdminUser?> {
  late final AuthRepository _repository;

  @override
  FutureOr<AdminUser?> build() async {
    _repository = ref.watch(authRepositoryProvider);
    return _initialize();
  }

  Future<AdminUser?> _initialize() async {
    try {
      final token = await _repository.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      final user = await _repository.getMe();
      return user;
    } catch (_) {
      await _repository.deleteToken();
      return null;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
    void Function()? onSuccess,
    void Function(String)? onFailure,
  }) async {
    if (state.isLoading) return;

    state = const AsyncValue.loading();
    try {
      final request = LoginRequest(identifier: identifier, password: password);
      final response = await _repository.login(request);

      await _repository.saveToken(response.accessToken);

      try {
        final user = await _repository.getMe();
        state = AsyncValue.data(user);
        onSuccess?.call();
      } catch (meError) {
        await _repository.deleteToken();
        state = const AsyncValue.data(null);
        rethrow;
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      onFailure?.call(e.toString());
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteToken();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSource(dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(remoteDataSource, secureStorage);
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AdminUser?>(AuthController.new);
