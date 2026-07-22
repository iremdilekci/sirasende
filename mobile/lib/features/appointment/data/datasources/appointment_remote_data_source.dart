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
            return const AppException(
              message:
                  'Bu saat az önce başka biri tarafından rezerve edildi. Lütfen farklı bir saat seçin.',
              code: 'CONFLICT',
            );
          } else if (statusCode == 404) {
            return const AppException(
              message: 'İşletme bulunamadı veya artık hizmet vermiyor.',
              code: 'NOT_FOUND',
            );
          } else if (statusCode == 422) {
            return const AppException(
              message: 'Girdiğiniz bilgileri kontrol edin.',
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
            return AppException(
              message:
                  'Randevu oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.',
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
    return AppException(
      message:
          'Randevu oluşturulurken bir sorun oluştu. Lütfen tekrar deneyin.',
      code: 'UNKNOWN',
    );
  }
}
