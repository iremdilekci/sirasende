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
                  contains('Geçersiz istek'),
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

    group('getAdminAppointments Tests', () {
      const dummyListResponse = [
        {
          'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
          'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
          'customer_name': 'Ahmet Can',
          'customer_phone': '05554443322',
          'customer_note': 'Saç tıraşı',
          'appointment_date': '2026-07-22',
          'start_time': '09:00',
          'end_time': '09:30',
          'status': 'pending',
          'created_at': '2026-07-22T08:00:00Z',
          'updated_at': '2026-07-22T08:00:00Z',
        },
      ];

      test('should execute GET with correct path and parameters', () async {
        mockAdapter.handler = (options) {
          expect(options.method, 'GET');
          expect(options.path, '/api/v1/admin/appointments');
          expect(options.queryParameters['date'], '2026-07-22');
          expect(options.queryParameters['status'], 'pending');
          return jsonResponse(dummyListResponse, 200);
        };

        final result = await dataSource.getAdminAppointments(
          date: '2026-07-22',
          status: 'pending',
        );

        expect(result.length, 1);
        expect(result.first.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
        expect(result.first.customerName, 'Ahmet Can');
        expect(result.first.status, 'pending');
      });

      test('should map 401 status to UNAUTHORIZED exception', () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Token expired'}, 401);
        };

        expect(
          () => dataSource.getAdminAppointments(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'UNAUTHORIZED')
                .having(
                  (e) => e.message,
                  'message',
                  contains('Oturumunuzun süresi doldu'),
                ),
          ),
        );
      });

      test('should map 403 status to FORBIDDEN exception', () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Business access is inactive'}, 403);
        };

        expect(
          () => dataSource.getAdminAppointments(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'FORBIDDEN')
                .having(
                  (e) => e.message,
                  'message',
                  contains('İşletme hesabı aktif değil'),
                ),
          ),
        );
      });
    });

    group('updateAppointmentStatus Tests', () {
      const dummyUpdateResponse = {
        'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
        'customer_name': 'Ahmet Can',
        'customer_phone': '05554443322',
        'customer_note': 'Saç tıraşı',
        'appointment_date': '2026-07-22',
        'start_time': '09:00',
        'end_time': '09:30',
        'status': 'confirmed',
        'created_at': '2026-07-22T08:00:00Z',
        'updated_at': '2026-07-22T08:00:00Z',
      };

      test('should execute PATCH with correct path and body', () async {
        mockAdapter.handler = (options) {
          expect(options.method, 'PATCH');
          expect(
            options.path,
            '/api/v1/admin/appointments/a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d/status',
          );
          expect(options.data['status'], 'confirmed');
          return jsonResponse(dummyUpdateResponse, 200);
        };

        final result = await dataSource.updateAppointmentStatus(
          id: 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
          status: 'confirmed',
        );

        expect(result.status, 'confirmed');
        expect(result.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      });

      test(
        'should map 409 status transition error to INVALID_TRANSITION',
        () async {
          mockAdapter.handler = (options) {
            return jsonResponse({
              'detail': 'Invalid appointment status transition',
            }, 409);
          };

          expect(
            () => dataSource.updateAppointmentStatus(
              id: 'id-1',
              status: 'completed',
            ),
            throwsA(
              isA<AppException>()
                  .having((e) => e.code, 'code', 'INVALID_TRANSITION')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('Randevu durumu bu aşamada güncellenemez'),
                  ),
            ),
          );
        },
      );

      test(
        'should map 409 completion before end time error to COMPLETION_NOT_ALLOWED',
        () async {
          mockAdapter.handler = (options) {
            return jsonResponse({
              'detail':
                  'Appointment cannot be completed before its end time has passed.',
            }, 409);
          };

          expect(
            () => dataSource.updateAppointmentStatus(
              id: 'id-1',
              status: 'completed',
            ),
            throwsA(
              isA<AppException>()
                  .having((e) => e.code, 'code', 'COMPLETION_NOT_ALLOWED')
                  .having(
                    (e) => e.message,
                    'message',
                    contains(
                      'henüz bitiş saatine ulaşmadığı için tamamlanamaz',
                    ),
                  ),
            ),
          );
        },
      );

      test(
        'should map 404 appointment not found error to APPOINTMENT_NOT_FOUND',
        () async {
          mockAdapter.handler = (options) {
            return jsonResponse({'detail': 'Appointment not found'}, 404);
          };

          expect(
            () => dataSource.updateAppointmentStatus(
              id: 'id-1',
              status: 'confirmed',
            ),
            throwsA(
              isA<AppException>()
                  .having((e) => e.code, 'code', 'APPOINTMENT_NOT_FOUND')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('Randevu bulunamadı veya artık geçerli değil'),
                  ),
            ),
          );
        },
      );
    });
  });
}
