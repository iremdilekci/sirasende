import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:sirasende_mobile/features/auth/domain/models/admin_user.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';

class FakeAuthController extends AuthController {
  AdminUser? valueOverride;
  int logoutCalls = 0;

  @override
  FutureOr<AdminUser?> build() async => valueOverride;

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncValue.data(null);
  }
}

void main() {
  group('AdminHomeScreen Widget Tests', () {
    const dummyUser = AdminUser(
      id: 'a1b2-c3d4',
      businessId: 'f5cc-3ed5',
      username: 'Ahmet Berber',
      email: 'ahmet@berber.com',
      isActive: true,
    );

    late FakeAuthController fakeController;

    setUp(() {
      fakeController = FakeAuthController();
      fakeController.valueOverride = dummyUser;
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => fakeController)],
        child: const MaterialApp(home: AdminHomeScreen()),
      );
    }

    testWidgets(
      'should render username, welcome header and appointments section correctly',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Esnaf Paneli'), findsOneWidget);
        expect(find.text('Hoş geldiniz'), findsOneWidget);
        expect(find.text('Ahmet Berber'), findsOneWidget);
        expect(find.text('Randevular'), findsOneWidget);
        expect(
          find.text('Gelen randevuları görün ve filtreleyin'),
          findsOneWidget,
        );

        // Verify technical IDs and token are NOT visible on screen
        expect(find.text('a1b2-c3d4'), findsNothing);
        expect(find.text('f5cc-3ed5'), findsNothing);
      },
    );

    testWidgets('should trigger logout when logout button is pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final logoutButton = find.widgetWithText(OutlinedButton, 'Çıkış Yap');
      await tester.ensureVisible(logoutButton);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(fakeController.logoutCalls, 1);
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
