import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../features/business/presentation/providers/business_providers.dart';
import '../../../../features/business/presentation/widgets/business_card.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';

class CustomerBusinessListScreen extends ConsumerWidget {
  const CustomerBusinessListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(businessesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'İşletmeler',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(businessesProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Texts
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Randevu almak istediğiniz işletmeyi seçin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Uygun gün ve saatleri görüntülemek için bir işletmeye dokunun.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: businessesAsync.when(
                loading: () => const AppLoadingIndicator(
                  message: 'İşletmeler yükleniyor...',
                ),
                error: (error, stackTrace) {
                  final errorMessage = error is AppException
                      ? error.message
                      : 'İşletmeler yüklenemedi.';
                  return AppEmptyState(
                    title: 'Hata Oluştu',
                    message: errorMessage,
                    icon: Icons.error_outline,
                    actionLabel: 'Tekrar Dene',
                    onAction: () {
                      ref.invalidate(businessesProvider);
                    },
                  );
                },
                data: (businesses) {
                  if (businesses.isEmpty) {
                    return AppEmptyState(
                      title: 'Henüz işletme bulunmuyor',
                      message:
                          'Aktif işletmeler eklendiğinde burada görünecek.',
                      icon: Icons.storefront_outlined,
                      actionLabel: 'Yenile',
                      onAction: () {
                        ref.invalidate(businessesProvider);
                      },
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => ref.refresh(businessesProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.s,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: businesses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final business = businesses[index];
                        return BusinessCard(
                          business: business,
                          onTap: () {
                            context.pushNamed(
                              RouteNames.customerBusinessDetail,
                              pathParameters: {'slug': business.slug},
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
