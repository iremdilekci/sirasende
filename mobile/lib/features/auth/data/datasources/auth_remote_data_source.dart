import 'package:dio/dio.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/network_constants.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  Future<TokenResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        NetworkConstants.login,
        data: request.toJson(),
      );
      if (response.data == null) {
        throw const AppException(
          message: 'Giriş yapılırken bir sorun oluştu. Lütfen tekrar deneyin.',
          code: 'SERVER_ERROR',
        );
      }
      return TokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleLoginError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Giriş yapılırken bir sorun oluştu. Lütfen tekrar deneyin.',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  Future<AdminUser> getMe() async {
    try {
      final response = await _dio.get(NetworkConstants.me);
      if (response.data == null) {
        throw const AppException(
          message:
              'Oturum doğrulanırken bir sorun oluştu. Lütfen tekrar deneyin.',
          code: 'SERVER_ERROR',
        );
      }
      return AdminUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleMeError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message:
            'Oturum doğrulanırken bir sorun oluştu. Lütfen tekrar deneyin.',
        code: 'UNKNOWN_ERROR',
      );
    }
  }

  AppException _handleLoginError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const AppException(
        message:
            'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        code: 'CONNECTION_ERROR',
      );
    }

    if (error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return const AppException(
          message: 'Kullanıcı adı/e-posta veya şifre hatalı.',
          code: 'UNAUTHORIZED',
        );
      } else if (statusCode == 422) {
        return const AppException(
          message: 'Giriş bilgilerinizi kontrol edin.',
          code: 'VALIDATION_ERROR',
        );
      } else if (statusCode == 500) {
        return const AppException(
          message: 'Sunucuda bir hata oluştu. Lütfen tekrar deneyin.',
          code: 'SERVER_ERROR',
        );
      }
    }

    return const AppException(
      message: 'Giriş yapılırken bir sorun oluştu. Lütfen tekrar deneyin.',
      code: 'UNKNOWN_ERROR',
    );
  }

  AppException _handleMeError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const AppException(
        message:
            'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        code: 'CONNECTION_ERROR',
      );
    }

    if (error.type == DioExceptionType.badResponse) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return const AppException(
          message: 'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.',
          code: 'UNAUTHORIZED',
        );
      } else if (statusCode == 403) {
        return const AppException(
          message: 'İşletme hesabı aktif değil.',
          code: 'FORBIDDEN',
        );
      } else if (statusCode == 500) {
        return const AppException(
          message: 'Sunucuda bir hata oluştu. Lütfen tekrar deneyin.',
          code: 'SERVER_ERROR',
        );
      }
    }

    return const AppException(
      message: 'Oturum doğrulanırken bir sorun oluştu. Lütfen tekrar deneyin.',
      code: 'UNKNOWN_ERROR',
    );
  }
}
