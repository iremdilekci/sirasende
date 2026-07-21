import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/constants/app_constants.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
