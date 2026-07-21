import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_placeholder_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/customer',
        name: RouteNames.customerHome,
        builder: (context, state) => const CustomerBusinessListScreen(),
      ),
      GoRoute(
        path: '/admin/login',
        name: RouteNames.adminLogin,
        builder: (context, state) => const AdminLoginPlaceholderScreen(),
      ),
    ],
  );
});
