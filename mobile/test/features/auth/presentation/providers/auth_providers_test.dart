import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';

class FakeAuthRepository implements AuthRepository {
  TokenResponse? loginResult;
  Object? loginError;
  int loginCalls = 0;

  AdminUser? meResult;
  Object? meError;
  int meCalls = 0;

  String? tokenValue;
  int saveTokenCalls = 0;
  int deleteTokenCalls = 0;

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
  Future<void> saveToken(String token) async {
    saveTokenCalls++;
    tokenValue = token;
  }

  @override
  Future<String?> getToken() async {
    return tokenValue;
  }

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    tokenValue = null;
  }
}

void main() {
  group('AuthController Provider Tests', () {
    late FakeAuthRepository fakeRepo;

    const dummyToken = TokenResponse(
      accessToken: 't123',
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

    setUp(() {
      fakeRepo = FakeAuthRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
    }

    test('should initialize to null if no token is found', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final state = await container.read(authControllerProvider.future);
      expect(state, isNull);
      expect(fakeRepo.meCalls, 0);
    });

    test('should initialize with User if token is present and valid', () async {
      fakeRepo.tokenValue = 'valid_token';
      fakeRepo.meResult = dummyUser;

      final container = createContainer();
      addTearDown(container.dispose);

      final state = await container.read(authControllerProvider.future);
      expect(state, dummyUser);
      expect(fakeRepo.meCalls, 1);
    });

    test(
      'should clear token and initialize with null if me fails on startup',
      () async {
        fakeRepo.tokenValue = 'invalid_token';
        fakeRepo.meError = const AppException(
          message: 'Expired',
          code: 'UNAUTHORIZED',
        );

        final container = createContainer();
        addTearDown(container.dispose);

        final state = await container.read(authControllerProvider.future);
        expect(state, isNull);
        expect(fakeRepo.tokenValue, isNull);
        expect(fakeRepo.deleteTokenCalls, 1);
      },
    );

    test(
      'should set state to loading and then user on login success',
      () async {
        fakeRepo.loginResult = dummyToken;
        fakeRepo.meResult = dummyUser;

        final container = createContainer();
        addTearDown(container.dispose);

        // Wait for initial build to complete
        await container.read(authControllerProvider.future);

        final notifier = container.read(authControllerProvider.notifier);
        final future = notifier.login(
          identifier: 'admin',
          password: 'password',
        );

        expect(container.read(authControllerProvider).isLoading, isTrue);

        await future;

        expect(container.read(authControllerProvider).value, dummyUser);
        expect(fakeRepo.tokenValue, 't123');
      },
    );

    test(
      'should rollback token and reset state if me fails after login',
      () async {
        fakeRepo.loginResult = dummyToken;
        fakeRepo.meError = const AppException(
          message: 'Inactive',
          code: 'FORBIDDEN',
        );

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(authControllerProvider.future);

        final notifier = container.read(authControllerProvider.notifier);
        await notifier.login(identifier: 'admin', password: 'password');

        expect(container.read(authControllerProvider).hasError, isTrue);
        expect(container.read(authControllerProvider).value, isNull);
        expect(fakeRepo.tokenValue, isNull); // Rolled back!
      },
    );

    test('should clear token and state on logout', () async {
      fakeRepo.tokenValue = 'some_token';
      fakeRepo.meResult = dummyUser;

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.logout();

      expect(container.read(authControllerProvider).value, isNull);
      expect(fakeRepo.tokenValue, isNull);
    });
  });
}
