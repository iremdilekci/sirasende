import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/google_calendar_providers.dart';

class GoogleCalendarCallbackScreen extends ConsumerStatefulWidget {
  final String? status;
  final String? error;

  const GoogleCalendarCallbackScreen({
    super.key,
    this.status,
    this.error,
  });

  @override
  ConsumerState<GoogleCalendarCallbackScreen> createState() =>
      _GoogleCalendarCallbackScreenState();
}

class _GoogleCalendarCallbackScreenState
    extends ConsumerState<GoogleCalendarCallbackScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Invalidate connection status to fetch the latest state from backend
      ref.invalidate(googleCalendarStatusProvider);
      
      // Auto-navigate to profile after 3 seconds
      _redirectTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          context.goNamed(RouteNames.adminProfile);
        }
      });
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == 'success';
    final errorMessage = widget.error ?? 'Google hesabı bağlanamadı. Lütfen tekrar deneyin.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Takvim Bağlantısı'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  isSuccess ? 'Bağlantı Başarılı!' : 'Bağlantı Başarısız!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  isSuccess
                      ? 'Google Takvim hesabınız başarıyla bağlandı. Profil sayfasına yönlendiriliyorsunuz...'
                      : errorMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      context.goNamed(RouteNames.adminProfile);
                    },
                    child: const Text('Profil Sayfasına Git'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
