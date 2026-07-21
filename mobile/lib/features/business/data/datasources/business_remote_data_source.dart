import 'package:dio/dio.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/network_constants.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';

class BusinessRemoteDataSource {
  final Dio _dio;

  BusinessRemoteDataSource(this._dio);

  Future<List<Business>> fetchBusinesses() async {
    try {
      final response = await _dio.get(NetworkConstants.businesses);
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Expected list response');
      }
      return data.map((json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map inside list');
        }
        return Business.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<Business> fetchBusinessBySlug(String slug) async {
    if (slug.isEmpty) {
      throw const AppException(
        message: 'Geçersiz işletme bilgisi (boş slug).',
        code: 'INVALID_SLUG',
      );
    }
    try {
      final response = await _dio.get(NetworkConstants.businessBySlug(slug));
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }
      return Business.fromJson(data);
    } catch (e) {
      throw _mapException(e);
    }
  }

  AppException _mapException(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const AppException(
            message: 'İstek zaman aşımına uğradı.',
            code: 'TIMEOUT',
          );
        case DioExceptionType.connectionError:
          return const AppException(
            message: 'Sunucuya bağlanılamadı.',
            code: 'CONNECTION_ERROR',
          );
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 404) {
            return const AppException(
              message: 'İşletme bulunamadı.',
              code: 'NOT_FOUND',
            );
          } else if (statusCode != null && statusCode >= 500) {
            return const AppException(
              message: 'Sunucuda bir hata oluştu.',
              code: 'SERVER_ERROR',
            );
          } else {
            return AppException(
              message:
                  'Sunucudan hata yanıtı alındı (${statusCode ?? "Bilinmiyor"}).',
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
