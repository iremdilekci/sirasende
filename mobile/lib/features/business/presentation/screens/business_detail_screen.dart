import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

class BusinessDetailScreen extends ConsumerWidget {
  final String slug;

  const BusinessDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(businessDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          businessAsync.whenOrNull(data: (b) => b)?.name ?? 'İşletme Detayı',
        ),
      ),
      body: SafeArea(
        child: businessAsync.when(
          loading: () => const AppLoadingIndicator(
            message: 'İşletme bilgileri yükleniyor...',
          ),
          error: (error, stackTrace) {
            final errorMessage = error is AppException
                ? error.message
                : 'İşletme bilgileri yüklenemedi.';
            return AppEmptyState(
              title: 'İşletme bilgileri yüklenemedi',
              message: errorMessage,
              icon: Icons.error_outline,
              actionLabel: 'Tekrar Dene',
              onAction: () {
                ref.invalidate(businessDetailProvider(slug));
              },
            );
          },
          data: (business) {
            final startTime = _formatTime(business.workingStartTime);
            final endTime = _formatTime(business.workingEndTime);
            final showWorkingHours = startTime.isNotEmpty && endTime.isNotEmpty;

            final showAddress =
                business.address != null && business.address!.isNotEmpty;
            final showPhone =
                business.phone != null && business.phone!.isNotEmpty;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withAlpha(128),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          if (showAddress) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.location_on_outlined,
                              title: 'Adres',
                              value: business.address!,
                            ),
                            if (showPhone || showWorkingHours || true)
                              const Divider(height: 24),
                          ],
                          if (showPhone) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.phone_outlined,
                              title: 'Telefon',
                              value: business.phone!,
                            ),
                            if (showWorkingHours || true)
                              const Divider(height: 24),
                          ],
                          _buildInfoRow(
                            context,
                            icon: Icons.access_time_outlined,
                            title: 'Randevu Süresi',
                            value: '${business.slotDurationMinutes} dakika',
                          ),
                          if (showWorkingHours) ...[
                            const Divider(height: 24),
                            _buildInfoRow(
                              context,
                              icon: Icons.schedule_outlined,
                              title: 'Çalışma Saatleri',
                              value: '$startTime – $endTime',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }
}
