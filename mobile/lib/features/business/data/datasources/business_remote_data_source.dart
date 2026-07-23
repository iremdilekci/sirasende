import 'package:dio/dio.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/network_constants.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';


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

  Future<List<Slot>> fetchBusinessSlots(String slug, String date) async {
    if (slug.isEmpty) {
      throw const AppException(
        message: 'Geçersiz işletme bilgisi (boş slug).',
        code: 'INVALID_SLUG',
      );
    }
    if (date.isEmpty) {
      throw const AppException(
        message: 'Geçersiz tarih bilgisi.',
        code: 'INVALID_DATE',
      );
    }
    try {
      final response = await _dio.get(
        NetworkConstants.businessSlots(slug),
        queryParameters: {'date': date},
      );
      final data = response.data;
      if (data is! List) {
        throw const FormatException('Expected list response');
      }
      return data.map((json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map inside list');
        }
        return Slot.fromJson(json);
      }).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<Business> fetchAdminBusiness() async {
    try {
      final response = await _dio.get(NetworkConstants.adminBusiness);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }
      return Business.fromJson(data);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<Business> updateAdminBusiness({
    required String name,
    String? description,
    String? phone,
    String? address,
    String? workingStartTime,
    String? workingEndTime,
    int? slotDurationMinutes,
    List<BusinessSchedule>? schedules,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'description': description,
        'phone': phone,
        'address': address,
        'working_start_time': workingStartTime,
        'working_end_time': workingEndTime,
        'slot_duration_minutes': slotDurationMinutes,
      };
      if (schedules != null) {
        payload['schedules'] = schedules.map((item) => item.toJson()).toList();
      }
      final response = await _dio.patch(
        NetworkConstants.adminBusiness,
        data: payload,
      );
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
            message:
                'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
            code: 'TIMEOUT',
          );
        case DioExceptionType.connectionError:
          return const AppException(
            message:
                'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
            code: 'CONNECTION_ERROR',
          );
        case DioExceptionType.badResponse:
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
          } else if (statusCode == 404) {
            return const AppException(
              message: 'İşletme bulunamadı veya artık hizmet vermiyor.',
              code: 'NOT_FOUND',
            );
          } else if (statusCode == 422) {
            return const AppException(
              message: 'Geçersiz istek.',
              code: 'VALIDATION_ERROR',
            );
          } else if (statusCode == 400) {
            final responseData = error.response?.data;
            if (responseData is Map<String, dynamic>) {
              final detail = responseData['detail'] as String?;
              if (detail != null) {
                if (detail.contains('past dates')) {
                  return const AppException(
                    message:
                        'Geçmiş tarihler için randevu saatleri sorgulanamaz.',
                    code: 'PAST_DATE_ERROR',
                  );
                }
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
              message:
                  'İşlem gerçekleştirilirken bir sorun oluştu. Lütfen tekrar deneyin.',
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
