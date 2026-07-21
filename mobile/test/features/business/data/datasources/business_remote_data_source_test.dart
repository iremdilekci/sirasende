import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/data/datasources/business_remote_data_source.dart';

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
  group('BusinessRemoteDataSource Tests', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late BusinessRemoteDataSource dataSource;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      dataSource = BusinessRemoteDataSource(dio);
    });

    ResponseBody jsonResponse(dynamic data, int statusCode) {
      final jsonString = jsonEncode(data);
      return ResponseBody.fromString(
        jsonString,
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    test('should fetch businesses list successfully', () async {
      final listData = [
        {
          'id': 'b1',
          'name': 'B1',
          'slug': 'b-1',
          'slot_duration_minutes': 15,
          'is_active': true,
        },
      ];

      mockAdapter.handler = (options) {
        expect(options.path, '/api/v1/businesses');
        expect(options.method, 'GET');
        return jsonResponse(listData, 200);
      };

      final result = await dataSource.fetchBusinesses();
      expect(result.length, 1);
      expect(result[0].name, 'B1');
    });

    test('should return empty list when no businesses exist', () async {
      mockAdapter.handler = (options) {
        return jsonResponse([], 200);
      };

      final result = await dataSource.fetchBusinesses();
      expect(result, isEmpty);
    });

    test('should fetch business detail by slug successfully', () async {
      final detailData = {
        'id': 'b1',
        'name': 'B1',
        'slug': 'b-1',
        'slot_duration_minutes': 15,
        'is_active': true,
        'working_start_time': '09:00:00',
        'working_end_time': '17:00:00',
      };

      mockAdapter.handler = (options) {
        expect(options.path, '/api/v1/businesses/b-1');
        return jsonResponse(detailData, 200);
      };

      final result = await dataSource.fetchBusinessBySlug('b-1');
      expect(result.name, 'B1');
      expect(result.workingStartTime, '09:00:00');
    });

    test(
      'should throw AppException with INVALID_SLUG when slug is empty',
      () async {
        expect(
          () => dataSource.fetchBusinessBySlug(''),
          throwsA(
            isA<AppException>().having((e) => e.code, 'code', 'INVALID_SLUG'),
          ),
        );
      },
    );

    test('should map 404 response to NOT_FOUND AppException', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Not found'}, 404);
      };

      expect(
        () => dataSource.fetchBusinessBySlug('unknown'),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'NOT_FOUND')),
      );
    });

    test('should map 500 response to SERVER_ERROR AppException', () async {
      mockAdapter.handler = (options) {
        return jsonResponse({'detail': 'Server error'}, 500);
      };

      expect(
        () => dataSource.fetchBusinesses(),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'SERVER_ERROR'),
        ),
      );
    });

    test('should map Timeout to TIMEOUT AppException', () async {
      mockAdapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      };

      expect(
        () => dataSource.fetchBusinesses(),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'TIMEOUT')),
      );
    });

    test('should map FormatException to INVALID_RESPONSE', () async {
      mockAdapter.handler = (options) {
        // Return bad data type
        return jsonResponse('not a list', 200);
      };

      expect(
        () => dataSource.fetchBusinesses(),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
    });
  });
}
