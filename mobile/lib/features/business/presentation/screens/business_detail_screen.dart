import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/router/route_names.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/business/domain/models/slot.dart';
import 'package:sirasende_mobile/features/business/presentation/helpers/datetime_helpers.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  final DateTime Function()? clock;

  const BusinessDetailScreen({super.key, required this.slug, this.clock});

  @override
  ConsumerState<BusinessDetailScreen> createState() =>
      _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  late DateTime _selectedDate;
  Slot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final now = widget.clock?.call() ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = widget.clock?.call() ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(businessDetailProvider(widget.slug));
    final formattedDate = formatDateToYmd(_selectedDate);

    final slotsParams = BusinessSlotsParams(
      slug: widget.slug,
      date: formattedDate,
    );
    final slotsAsync = ref.watch(businessSlotsProvider(slotsParams));

    ref.listen<AsyncValue<List<Slot>>>(businessSlotsProvider(slotsParams), (
      prev,
      next,
    ) {
      if (next.isLoading ||
          next.hasError ||
          (next.hasValue && next.value!.isEmpty)) {
        if (_selectedSlot != null) {
          setState(() {
            _selectedSlot = null;
          });
        }
      } else if (next.hasValue && _selectedSlot != null) {
        final exists = next.value!.any(
          (s) => s.startTime == _selectedSlot!.startTime && s.available,
        );
        if (!exists) {
          setState(() {
            _selectedSlot = null;
          });
        }
      }
    });

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
                ref.invalidate(businessDetailProvider(widget.slug));
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
                  Text(
                    'Randevu Tarihi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              formatTurkishDate(_selectedDate),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Müsait Saatler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  slotsAsync.when(
                    loading: () => const AppLoadingIndicator(
                      message: 'Müsait saatler yükleniyor...',
                    ),
                    error: (error, stackTrace) {
                      final errorMessage = error is AppException
                          ? error.message
                          : 'Müsait saatler yüklenemedi.';
                      return AppEmptyState(
                        title: 'Müsait saatler yüklenemedi',
                        message: errorMessage,
                        icon: Icons.error_outline,
                        actionLabel: 'Tekrar Dene',
                        onAction: () {
                          ref.invalidate(businessSlotsProvider(slotsParams));
                        },
                      );
                    },
                    data: (List<Slot> slots) {
                      final availableSlots = slots
                          .where((s) => s.available == true)
                          .toList();

                      if (availableSlots.isEmpty) {
                        return const AppEmptyState(
                          title: 'Müsait saat bulunamadı',
                          message:
                              'Bu tarih için uygun randevu saati bulunmuyor. Başka bir tarih seçebilirsiniz.',
                          icon: Icons.access_time_filled_outlined,
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableSlots.map((slot) {
                          final isSelected = _selectedSlot == slot;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedSlot = null;
                                } else {
                                  _selectedSlot = slot;
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                slot.startTime,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Continuation Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _selectedSlot == null || slotsAsync.isLoading
                          ? null
                          : () {
                              context.pushNamed(
                                RouteNames.customerAppointmentForm,
                                pathParameters: {'slug': widget.slug},
                                extra: AppointmentFormArgs(
                                  businessSlug: widget.slug,
                                  businessName: business.name,
                                  date: formattedDate,
                                  startTime: _selectedSlot!.startTime,
                                  endTime: _selectedSlot!.endTime,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Devam Et',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
