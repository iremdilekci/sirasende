import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_registration_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/registration_success_screen.dart';
import 'package:sirasende_mobile/features/auth/data/models/login_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/registration_request.dart';
import 'package:sirasende_mobile/features/auth/data/models/registration_response.dart';
import 'package:sirasende_mobile/features/auth/data/models/token_response.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';

class FakeAuthRepository implements AuthRepository {
  RegistrationRequest? lastRegisterRequest;
  int registerCalls = 0;
  Object? registerError;

  @override
  Future<RegistrationResponse> register(RegistrationRequest request) async {
    registerCalls++;
    lastRegisterRequest = request;
    if (registerError != null) {
      throw registerError!;
    }
    return RegistrationResponse(
      adminId: 'a123',
      businessId: 'b123',
      username: request.username,
      email: request.email,
      businessName: request.businessName,
      message: 'Kayıt başarılı',
    );
  }

  @override
  Future<TokenResponse> login(LoginRequest request) async {
    return const TokenResponse(
      accessToken: 't123',
      tokenType: 'bearer',
      expiresIn: 3600,
    );
  }

  @override
  Future<AdminUser> getMe() async {
    return const AdminUser(
      id: 'a123',
      businessId: 'b123',
      username: 'user',
      email: 'user@test.com',
      isActive: true,
    );
  }

  @override
  Future<void> saveToken(String token) async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}
}

void main() {
  group('AdminRegistrationScreen Tests', () {
    late FakeAuthRepository fakeRepo;
    late GoRouter router;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(
            path: '/login',
            name: RouteNames.adminLogin,
            builder: (context, state) {
              final extra = state.extra;
              final prefilled = extra is String ? extra : null;
              return AdminLoginScreen(prefilledIdentifier: prefilled);
            },
          ),
          GoRoute(
            path: '/register',
            name: RouteNames.adminRegister,
            builder: (context, state) => const AdminRegistrationScreen(),
          ),
          GoRoute(
            path: '/register/success',
            name: RouteNames.adminRegisterSuccess,
            builder: (context, state) {
              final extra = state.extra;
              final prefilled = extra is String ? extra : null;
              return RegistrationSuccessScreen(prefilledIdentifier: prefilled);
            },
          ),
        ],
      );
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('renders all form inputs and validation errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check header and sections
      expect(find.text('İşletme Kaydı'), findsOneWidget);
      expect(find.text('İşletme Bilgileri'), findsOneWidget);
      expect(find.text('Hesap Bilgileri'), findsOneWidget);

      // Tap submit to trigger validation
      final submitButton = find.widgetWithText(FilledButton, 'Kaydol');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Expect validation messages
      expect(find.text('İşletme adı zorunludur.'), findsOneWidget);
      expect(find.text('Kullanıcı adı zorunludur.'), findsOneWidget);
      expect(find.text('E-posta adresi zorunludur.'), findsOneWidget);
      expect(find.text('Şifre zorunludur.'), findsOneWidget);
    });

    testWidgets(
      'successful registration navigates to success and pre-fills login on return',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Fill in valid details
        await tester.enterText(
          find.widgetWithText(TextFormField, 'İşletme Adı *'),
          'My Barber',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Kullanıcı Adı *'),
          'my_barber',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'E-posta Adresi *'),
          'barber@shop.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Şifre *'),
          'password123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Şifre Tekrar *'),
          'password123',
        );

        final submitButton = find.widgetWithText(FilledButton, 'Kaydol');
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Should call repository once
        expect(fakeRepo.registerCalls, 1);
        expect(fakeRepo.lastRegisterRequest?.businessName, 'My Barber');
        expect(fakeRepo.lastRegisterRequest?.username, 'my_barber');
        expect(fakeRepo.lastRegisterRequest?.email, 'barber@shop.com');
        // Verify passwordConfirm is not sent inside RegistrationRequest
        expect(
          fakeRepo.lastRegisterRequest?.toJson().containsKey(
            'password_confirm',
          ),
          isFalse,
        );

        // Navigated to Success Screen
        expect(find.text('Tebrikler!'), findsOneWidget);

        // Tap Return to Login
        final loginButton = find.widgetWithText(FilledButton, 'Giriş Yap');
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        // Replaced stack: now on login screen with prefilled identifier!
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.byType(RegistrationSuccessScreen), findsNothing);
        expect(router.canPop(), isFalse);

        // Check text controller value is prefilled with email
        final idField = find.widgetWithText(
          TextFormField,
          'Kullanıcı adı veya e-posta',
        );
        expect(
          tester.widget<TextFormField>(idField).controller?.text,
          'barber@shop.com',
        );
      },
    );

    testWidgets('shows error snackbar on 409 conflict and does not crash', (
      WidgetTester tester,
    ) async {
      fakeRepo.registerError = const AppException(
        message: 'Bu kullanıcı adı veya e-posta adresi zaten alınmış.',
        code: 'CONFLICT',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Fill in details
      await tester.enterText(
        find.widgetWithText(TextFormField, 'İşletme Adı *'),
        'My Barber',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı Adı *'),
        'my_barber',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta Adresi *'),
        'barber@shop.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre *'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre Tekrar *'),
        'password123',
      );

      final submitButton = find.widgetWithText(FilledButton, 'Kaydol');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Shows SnackBar
      expect(
        find.text('Bu kullanıcı adı veya e-posta adresi zaten alınmış.'),
        findsOneWidget,
      );
    });

    testWidgets('scrolls and prevents overflow on 320x568 layout', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3.0, 568 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
