import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:sirasende_mobile/features/customer/presentation/screens/customer_business_list_screen.dart';
import 'package:sirasende_mobile/features/admin/presentation/screens/admin_login_placeholder_screen.dart';
import 'package:sirasende_mobile/features/business/presentation/screens/business_detail_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_form_screen.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_success_args.dart';
import 'package:sirasende_mobile/features/appointment/presentation/screens/appointment_success_screen.dart';

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
        routes: [
          GoRoute(
            path: 'businesses/:slug',
            name: RouteNames.customerBusinessDetail,
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return BusinessDetailScreen(slug: slug);
            },
            routes: [
              GoRoute(
                path: 'appointment',
                name: RouteNames.customerAppointmentForm,
                builder: (context, state) {
                  final args = state.extra;
                  if (args is AppointmentFormArgs) {
                    return AppointmentFormScreen(args: args);
                  }
                  return const Scaffold(
                    body: Center(child: Text('Geçersiz sayfa parametreleri.')),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'appointment/success',
            name: RouteNames.customerAppointmentSuccess,
            builder: (context, state) {
              final args = state.extra;
              if (args is AppointmentSuccessArgs) {
                return AppointmentSuccessScreen(args: args);
              }
              return const Scaffold(
                body: Center(child: Text('Geçersiz sayfa parametreleri.')),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/login',
        name: RouteNames.adminLogin,
        builder: (context, state) => const AdminLoginPlaceholderScreen(),
      ),
    ],
  );
});
