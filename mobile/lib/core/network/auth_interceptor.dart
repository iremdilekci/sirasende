import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/storage/secure_storage_provider.dart';

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip appending token for login endpoint
    if (options.path.endsWith('/api/v1/auth/login')) {
      return handler.next(options);
    }

    final secureStorage = _ref.read(secureStorageProvider);
    final token = await secureStorage.read(key: 'admin_jwt_token');

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }
}
