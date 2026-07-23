import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';

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
  group('AuthRemoteDataSource Tests', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late AuthRemoteDataSource dataSource;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      dataSource = AuthRemoteDataSource(dio);
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

    const dummyLoginRequest = LoginRequest(
      identifier: 'admin@example.com',
      password: 'password123',
    );

    const dummyTokenResponse = {
      'access_token': 'token_xyz_123',
      'token_type': 'bearer',
      'expires_in': 1800,
    };

    const dummyUserResponse = {
      'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      'business_id': 'f5cc002d-3ed5-478e-3614-58f86d80b65c',
      'username': 'admin_username',
      'email': 'admin@example.com',
      'is_active': true,
    };

    test(
      'should execute POST login with correct path, parameters, and parse response',
      () async {
        mockAdapter.handler = (options) {
          expect(options.method, 'POST');
          expect(options.path, '/api/v1/auth/login');
          expect(options.data['identifier'], 'admin@example.com');
          expect(options.data['password'], 'password123');
          return jsonResponse(dummyTokenResponse, 200);
        };

        final response = await dataSource.login(dummyLoginRequest);
        expect(response.accessToken, 'token_xyz_123');
        expect(response.tokenType, 'bearer');
        expect(response.expiresIn, 1800);
      },
    );

    test(
      'should execute GET /auth/me with correct path and parse user profile',
      () async {
        mockAdapter.handler = (options) {
          expect(options.method, 'GET');
          expect(options.path, '/api/v1/auth/me');
          return jsonResponse(dummyUserResponse, 200);
        };

        final response = await dataSource.getMe();
        expect(response.id, 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
        expect(response.username, 'admin_username');
      },
    );

    test('should map login 401 to UNAUTHORIZED exception', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Invalid credentials'}, 401);
      };

      expect(
        () => dataSource.login(dummyLoginRequest),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'UNAUTHORIZED')
              .having(
                (e) => e.message,
                'message',
                contains('Kullanıcı adı/e-posta veya şifre hatalı.'),
              ),
        ),
      );
    });

    test('should map login 422 to VALIDATION_ERROR exception', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Validation details'}, 422);
      };

      expect(
        () => dataSource.login(dummyLoginRequest),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having(
                (e) => e.message,
                'message',
                contains('Giriş bilgilerinizi kontrol edin.'),
              ),
        ),
      );
    });

    test(
      'should map getMe 401 to UNAUTHORIZED session expired exception',
      () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Signature has expired'}, 401);
        };

        expect(
          () => dataSource.getMe(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'UNAUTHORIZED')
                .having(
                  (e) => e.message,
                  'message',
                  contains(
                    'Oturumunuzun süresi doldu. Lütfen tekrar giriş yapın.',
                  ),
                ),
          ),
        );
      },
    );

    test(
      'should map getMe 403 to FORBIDDEN inactive business exception',
      () async {
        mockAdapter.handler = (options) {
          return jsonResponse({'detail': 'Business access is inactive'}, 403);
        };

        expect(
          () => dataSource.getMe(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', 'FORBIDDEN')
                .having(
                  (e) => e.message,
                  'message',
                  contains('İşletme hesabı aktif değil.'),
                ),
          ),
        );
      },
    );

    test('should map network timeout to CONNECTION_ERROR exception', () async {
      mockAdapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      };

      expect(
        () => dataSource.login(dummyLoginRequest),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'CONNECTION_ERROR')
              .having(
                (e) => e.message,
                'message',
                contains('Sunucuya ulaşılamadı.'),
              ),
        ),
      );
    });
  });
}
