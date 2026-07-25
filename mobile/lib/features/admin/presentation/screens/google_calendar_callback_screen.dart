import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/core/theme/app_colors.dart';
import 'package:sirasende_mobile/core/theme/app_spacing.dart';
import 'package:sirasende_mobile/core/theme/app_radius.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/google_calendar_providers.dart';

class GoogleCalendarCallbackScreen extends ConsumerStatefulWidget {
  final String? status;
  final String? error;

  const GoogleCalendarCallbackScreen({super.key, this.status, this.error});

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

      // Auto-navigate to profile after 3 seconds only if successful
      if (widget.status == 'success') {
        _redirectTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            context.goNamed(RouteNames.adminProfile);
          }
        });
      }
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
    final errorMessage =
        widget.error ?? 'Google hesabı bağlanamadı. Lütfen tekrar deneyin.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Google Takvim Bağlantısı', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false, // Prevent going back via back button
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? AppColors.success : AppColors.error,
                  size: 80,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  isSuccess ? 'Bağlantı Başarılı!' : 'Bağlantı Başarısız!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isSuccess
                      ? 'Google Takvim hesabınız başarıyla bağlandı. Profil sayfasına yönlendiriliyorsunuz...'
                      : errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),
                if (!isSuccess) ...[
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Tekrar Dene',
                      onPressed: () {
                        context.goNamed(RouteNames.adminProfile);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Profile Dön',
                    isOutlined: !isSuccess,
                    onPressed: () {
                      context.goNamed(RouteNames.adminProfile);
                    },
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
