import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/theme/app_theme.dart';
import 'package:sirasende_mobile/core/router/app_router.dart';

class SiraSendeApp extends ConsumerWidget {
  const SiraSendeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SıraSende',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
