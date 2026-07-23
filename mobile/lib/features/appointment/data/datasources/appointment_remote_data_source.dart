import 'package:dio/dio.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/network/network_constants.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';

class AppointmentRemoteDataSource {
  final Dio _dio;

  AppointmentRemoteDataSource(this._dio);

  Future<Appointment> createAppointment({
    required String businessSlug,
    required AppointmentCreateRequest request,
  }) async {
    if (businessSlug.isEmpty) {
      throw const AppException(
        message: 'Geçersiz işletme bilgisi (boş slug).',
        code: 'INVALID_SLUG',
      );
    }

    try {
      final url = NetworkConstants.createAppointment(businessSlug);
      final response = await _dio.post(url, data: request.toJson());

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }

      return Appointment.fromJson(data);
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<List<Appointment>> getAdminAppointments({
    String? date,
    String? status,
  }) async {
    try {
      final Map<String, dynamic> queryParameters = {};
      if (date != null && date.isNotEmpty) {
        queryParameters['date'] = date;
      }
      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }

      final response = await _dio.get(
        NetworkConstants.adminAppointments,
        queryParameters: queryParameters,
      );

      final data = response.data;
      if (data is! List) {
        throw const FormatException('Expected JSON list response');
      }

      return data
          .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<Appointment> updateAppointmentStatus({
    required String id,
    required String status,
  }) async {
    try {
      final response = await _dio.patch(
        '${NetworkConstants.adminAppointments}/${Uri.encodeComponent(id)}/status',
        data: {'status': status},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON map response');
      }

      return Appointment.fromJson(data);
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

          if (statusCode == 409) {
            final data = error.response?.data;
            if (data is Map<String, dynamic>) {
              final detail = data['detail'] as String?;
              if (detail != null) {
                if (detail.contains('status transition')) {
                  return const AppException(
                    message: 'Randevu durumu bu aşamada güncellenemez.',
                    code: 'INVALID_TRANSITION',
                  );
                } else if (detail.contains('completed before')) {
                  return const AppException(
                    message:
                        'Randevu henüz bitiş saatine ulaşmadığı için tamamlanamaz.',
                    code: 'COMPLETION_NOT_ALLOWED',
                  );
                }
              }
            }
            return const AppException(
              message:
                  'Bu saat az önce başka biri tarafından rezerve edildi. Lütfen farklı bir saat seçin.',
              code: 'CONFLICT',
            );
          } else if (statusCode == 401) {
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
            final data = error.response?.data;
            if (data is Map<String, dynamic>) {
              final detail = data['detail'] as String?;
              if (detail != null && detail.contains('Appointment not found')) {
                return const AppException(
                  message: 'Randevu bulunamadı veya artık geçerli değil.',
                  code: 'APPOINTMENT_NOT_FOUND',
                );
              }
            }
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
            return const AppException(
              message:
                  'Randevu bilgileri geçerli değil. Tarih ve saat seçiminizi kontrol edin.',
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
            message:
                'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
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
    return const AppException(
      message:
          'İşlem gerçekleştirilirken bir sorun oluştu. Lütfen tekrar deneyin.',
      code: 'UNKNOWN',
    );
  }
}
