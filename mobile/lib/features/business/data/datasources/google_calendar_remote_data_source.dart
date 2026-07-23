import 'package:dio/dio.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/network_constants.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connect_result.dart';
import 'package:sirasende_mobile/features/business/domain/models/google_calendar_connection_status.dart';

class GoogleCalendarRemoteDataSource {
  final Dio _dio;

  GoogleCalendarRemoteDataSource(this._dio);

  Future<GoogleCalendarConnectionStatus> fetchConnectionStatus() async {
    try {
      final response = await _dio.get(NetworkConstants.googleCalendarStatus);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }
      return GoogleCalendarConnectionStatus.fromJson(data);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<GoogleCalendarConnectResult> fetchConnectUrl() async {
    try {
      final response = await _dio.post(NetworkConstants.googleCalendarConnect);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }
      return GoogleCalendarConnectResult.fromJson(data);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> deleteConnection() async {
    try {
      await _dio.delete(NetworkConstants.googleCalendarConnection);
    } catch (e) {
      throw _mapException(e);
    }
  }

  AppException _mapException(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const AppException(
            message: 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
            code: 'TIMEOUT',
          );
        case DioExceptionType.badResponse:
          if (statusCode == 401) {
            return const AppException(
              message: 'Oturum süresi doldu. Lütfen yeniden giriş yapın.',
              code: 'UNAUTHORIZED',
            );
          } else if (statusCode == 404) {
            return const AppException(
              message: 'Bulunamadı.',
              code: 'NOT_FOUND',
            );
          } else if (statusCode == 400) {
            final responseData = error.response?.data;
            if (responseData is Map<String, dynamic>) {
              final detail = responseData['detail'] as String?;
              if (detail != null) {
                return AppException(message: detail, code: 'BAD_REQUEST');
              }
            }
            return const AppException(
              message: 'Bilgiler geçerli değil. Girişlerinizi kontrol edin.',
              code: 'BAD_REQUEST',
            );
          } else if (statusCode != null && statusCode >= 500) {
            return const AppException(
              message: 'Sunucuda bir hata oluştu. Lütfen tekrar deneyin.',
              code: 'SERVER_ERROR',
            );
          } else {
            return const AppException(
              message: 'İşlem gerçekleştirilirken bir sorun oluştu.',
              code: 'BAD_RESPONSE',
            );
          }
        default:
          return const AppException(
            message: 'Beklenmeyen bir ağ hatası oluştu.',
            code: 'NETWORK_ERROR',
          );
      }
    } else if (error is FormatException) {
      return const AppException(
        message: 'Sunucudan geçersiz bir yanıt alındı.',
        code: 'INVALID_RESPONSE',
      );
    } else if (error is AppException) {
      return error;
    }
    return AppException(
      message: 'Bilinmeyen bir hata oluştu: $error',
      code: 'UNKNOWN',
    );
  }
}
