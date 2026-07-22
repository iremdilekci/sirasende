import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/appointment/data/datasources/appointment_remote_data_source.dart';
import 'package:sirasende_mobile/features/appointment/data/models/appointment_create_request.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler != null) {
      return handler!(options);
    }
    throw UnimplementedError();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AppointmentRemoteDataSource Tests', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late AppointmentRemoteDataSource dataSource;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      dataSource = AppointmentRemoteDataSource(dio);
    });

    ResponseBody jsonResponse(dynamic data, int statusCode) {
      return ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    const dummyRequest = AppointmentCreateRequest(
      customerName: 'Ahmet Can',
      customerPhone: '05554443322',
      appointmentDate: '2026-07-22',
      startTime: '09:00',
    );

    const dummyResponseJson = {
      'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
      'customer_name': 'Ahmet Can',
      'customer_phone': '05554443322',
      'customer_note': null,
      'appointment_date': '2026-07-22',
      'start_time': '09:00',
      'end_time': '09:30',
      'status': 'pending',
      'created_at': '2026-07-22T20:00:00Z',
      'updated_at': '2026-07-22T20:00:00Z',
    };

    test(
      'should execute POST request to correct endpoint with body and parse response',
      () async {
        mockAdapter.handler = (options) {
          expect(options.method, 'POST');
          expect(options.path, '/api/v1/businesses/berber-ahmet/appointments');
          expect(options.data['customer_name'], 'Ahmet Can');
          expect(options.data['customer_phone'], '05554443322');
          expect(options.data.containsKey('end_time'), isFalse);
          return jsonResponse(dummyResponseJson, 201);
        };

        final result = await dataSource.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        );

        expect(result.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
        expect(result.customerName, 'Ahmet Can');
      },
    );

    test('should map 409 Conflict code to CONFLICT exception', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({
          'detail': 'Appointment slot is already booked',
        }, 409);
      };

      expect(
        () => dataSource.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'CONFLICT')
              .having(
                (e) => e.message,
                'message',
                contains(
                  'Bu saat az önce başka biri tarafından rezerve edildi',
                ),
              ),
        ),
      );
    });

    test('should map 404 Not Found code to NOT_FOUND exception', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Business not found'}, 404);
      };

      expect(
        () => dataSource.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'NOT_FOUND')
              .having(
                (e) => e.message,
                'message',
                contains('İşletme bulunamadı'),
              ),
        ),
      );
    });

    test('should map 400 Bad Request code to BAD_REQUEST exception', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Invalid appointment slot'}, 400);
      };

      expect(
        () => dataSource.createAppointment(
          businessSlug: 'berber-ahmet',
          request: dummyRequest,
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'BAD_REQUEST')
              .having(
                (e) => e.message,
                'message',
                contains('Tarih ve saat seçiminizi kontrol edin'),
              ),
        ),
      );
    });

    test(
      'should map 422 Validation error code to VALIDATION_ERROR exception',
      () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Validation error details'}, 422);
        };

        expect(
          () => dataSource.createAppointment(
            businessSlug: 'berber-ahmet',
            request: dummyRequest,
          ),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'VALIDATION_ERROR')
                .having(
                  (e) => e.message,
                  'message',
                  contains('Girdiğiniz bilgileri kontrol edin'),
                ),
          ),
        );
      },
    );

    test(
      'should map 500 Server error code to SERVER_ERROR exception',
      () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Internal Server Error'}, 500);
        };

        expect(
          () => dataSource.createAppointment(
            businessSlug: 'berber-ahmet',
            request: dummyRequest,
          ),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'SERVER_ERROR')
                .having(
                  (e) => e.message,
                  'message',
                  contains('Sunucuda bir hata oluştu'),
                ),
          ),
        );
      },
    );
  });
}
