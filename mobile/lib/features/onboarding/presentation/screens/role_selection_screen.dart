import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/constants/app_constants.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // Auth başlangıç kontrolü tamamlanana kadar kontrollü splash/loading ekranı göster.
    if (authState.isLoading && authState.value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Randevunuzu kolayca oluşturun veya işletmenizi yönetin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  AppButton(
                    label: 'Müşteri olarak devam et',
                    onPressed: () => context.goNamed(RouteNames.customerHome),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Esnaf girişi',
                    onPressed: () => context.goNamed(RouteNames.adminLogin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
