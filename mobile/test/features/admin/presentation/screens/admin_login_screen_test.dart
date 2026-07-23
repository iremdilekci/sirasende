import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';

class FakeAuthController extends AuthController {
  Object? errorOverride;
  bool isLoader = false;
  int loginCalls = 0;

  @override
  FutureOr<AdminUser?> build() async {
    if (isLoader) {
      state = const AsyncValue.loading();
    }
    if (errorOverride != null) {
      state = AsyncValue.error(errorOverride!, StackTrace.current);
    }
    return null;
  }

  @override
  Future<void> login({
    required String identifier,
    required String password,
    void Function()? onSuccess,
    void Function(String)? onFailure,
  }) async {
    loginCalls++;
    if (errorOverride != null) {
      state = AsyncValue.error(errorOverride!, StackTrace.current);
      onFailure?.call(errorOverride.toString());
    } else {
      state = const AsyncValue.data(
        AdminUser(
          id: 'u1',
          businessId: 'b1',
          username: 'Admin',
          email: 'a@a.com',
          isActive: true,
        ),
      );
      onSuccess?.call();
    }
  }
}

void main() {
  group('AdminLoginScreen Widget Tests', () {
    late FakeAuthController fakeController;

    setUp(() {
      fakeController = FakeAuthController();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => fakeController)],
        child: const MaterialApp(home: AdminLoginScreen()),
      );
    }

    testWidgets('should show validation warnings when fields are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Giriş Yap');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        find.text('Kullanıcı adı veya e-posta alanı zorunludur.'),
        findsOneWidget,
      );
      expect(find.text('Şifre alanı zorunludur.'), findsOneWidget);
      expect(fakeController.loginCalls, 0);
    });

    testWidgets('should call login on submit with valid inputs exactly once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı adı veya e-posta'),
        'admin_user',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'pass123',
      );

      final button = find.widgetWithText(FilledButton, 'Giriş Yap');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(fakeController.loginCalls, 1);
    });

    testWidgets(
      'should show 401 error message when login fails with Unauthorized',
      (WidgetTester tester) async {
        fakeController.errorOverride = const AppException(
          message: 'Kullanıcı adı/e-posta veya şifre hatalı.',
          code: 'UNAUTHORIZED',
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Kullanıcı adı veya e-posta'),
          'admin_user',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Şifre'),
          'wrong_pass',
        );

        final button = find.widgetWithText(FilledButton, 'Giriş Yap');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(
          find.text('Kullanıcı adı/e-posta veya şifre hatalı.'),
          findsOneWidget,
        );

        // Verify identifier field is preserved, password field is cleared
        expect(
          find.widgetWithText(TextFormField, 'admin_user'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, ''),
          findsOneWidget,
        ); // Password cleared
      },
    );

    testWidgets('should show connection error message when timeout occurs', (
      WidgetTester tester,
    ) async {
      fakeController.errorOverride = const AppException(
        message:
            'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        code: 'CONNECTION_ERROR',
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kullanıcı adı veya e-posta'),
        'admin_user',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'pass123',
      );

      final button = find.widgetWithText(FilledButton, 'Giriş Yap');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should not overflow on small screens', (
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
