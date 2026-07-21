import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/business/presentation/widgets/business_card.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

class CustomerBusinessListScreen extends ConsumerWidget {
  const CustomerBusinessListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(businessesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('İşletmeler')),
      body: SafeArea(
        child: businessesAsync.when(
          loading: () =>
              const AppLoadingIndicator(message: 'İşletmeler yükleniyor...'),
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
              return const AppEmptyState(
                title: 'Henüz işletme bulunmuyor',
                message: 'Aktif işletmeler eklendiğinde burada görünecek.',
                icon: Icons.business_outlined,
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(businessesProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16.0,
                ),
                itemCount: businesses.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return BusinessCard(business: business, onTap: null);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
