import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/data/models/registration_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/registration_response.dart';
import 'package:sirasende_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic options,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic options,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> delete({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic options,
  }) async {
    _storage.remove(key);
  }
}

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  TokenResponse? loginResult;
  Object? loginError;
  int loginCalls = 0;

  AdminUser? meResult;
  Object? meError;
  int meCalls = 0;

  @override
  Future<TokenResponse> login(LoginRequest request) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AdminUser> getMe() async {
    meCalls++;
    if (meError != null) throw meError!;
    return meResult!;
  }

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    return const RegistrationResponse(
      adminId: 'a1',
      businessId: 'b1',
      username: 'user',
      email: 'user@test.com',
      businessName: 'Biz',
      message: 'Success',
    );
  }
}

void main() {
  group('AuthRepositoryImpl Tests', () {
    late FakeAuthRemoteDataSource fakeRemoteDS;
    late FakeFlutterSecureStorage fakeSecureStorage;
    late AuthRepositoryImpl repository;

    setUp(() {
      fakeRemoteDS = FakeAuthRemoteDataSource();
      fakeSecureStorage = FakeFlutterSecureStorage();
      repository = AuthRepositoryImpl(fakeRemoteDS, fakeSecureStorage);
    });

    const dummyRequest = LoginRequest(
      identifier: 'admin',
      password: 'password',
    );
    const dummyToken = TokenResponse(
      accessToken: 'token123',
      tokenType: 'bearer',
      expiresIn: 1800,
    );
    const dummyUser = AdminUser(
      id: 'u1',
      businessId: 'b1',
      username: 'admin',
      email: 'a@a.com',
      isActive: true,
    );

    test('should delegate login to remote data source', () async {
      fakeRemoteDS.loginResult = dummyToken;

      final res = await repository.login(dummyRequest);
      expect(res, dummyToken);
      expect(fakeRemoteDS.loginCalls, 1);
    });

    test('should delegate getMe to remote data source', () async {
      fakeRemoteDS.meResult = dummyUser;

      final res = await repository.getMe();
      expect(res, dummyUser);
      expect(fakeRemoteDS.meCalls, 1);
    });

    test(
      'should delegate saveToken, getToken, and deleteToken to secure storage',
      () async {
        await repository.saveToken('my_jwt_value');
        expect(await repository.getToken(), 'my_jwt_value');

        await repository.deleteToken();
        expect(await repository.getToken(), isNull);
      },
    );
  });
}
