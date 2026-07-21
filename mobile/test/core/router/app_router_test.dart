import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/app.dart';
import 'package:sirasende_mobile/core/router/app_router.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_placeholder_screen.dart';

void main() {
  group('GoRouter Tests', () {
    testWidgets('should load role selection screen on root path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));
      await tester.pumpAndSettle();

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });

    testWidgets('should load customer home placeholder on /customer path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/customer');
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBusinessListScreen), findsOneWidget);
    });

    testWidgets('should load admin login placeholder on /admin/login path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: SiraSendeApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SiraSendeApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/admin/login');
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginPlaceholderScreen), findsOneWidget);
    });
  });
}
