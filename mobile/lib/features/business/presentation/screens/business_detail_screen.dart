import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../features/appointment/presentation/models/appointment_form_args.dart';
import '../../../../features/business/domain/models/slot.dart';
import '../../../../features/business/presentation/helpers/datetime_helpers.dart';
import '../../../../features/business/presentation/providers/business_providers.dart';
import '../../../../features/business/domain/models/business_schedule.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_card.dart';

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
  bool _isHoursExpanded = true;

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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

    final business = businessAsync.whenOrNull(data: (b) => b);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          business?.name ?? 'İşletme Detayı',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: businessAsync.when(
          loading: () => const AppLoadingIndicator(
            message: 'İşletme bilgileri yükleniyor...',
          ),
          error: (error, stackTrace) => AppEmptyState(
            title: 'İşletme bilgileri yüklenemedi',
            message: 'Lütfen tekrar deneyin.',
            icon: Icons.error_outline,
            actionLabel: 'Tekrar Dene',
            onAction: () {
              ref.invalidate(businessDetailProvider(widget.slug));
            },
          ),
          data: (business) {
            final showAddress =
                business.address != null && business.address!.isNotEmpty;
            final showPhone =
                business.phone != null && business.phone!.isNotEmpty;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Info Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    business.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    business.todayScheduleText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (business.description != null &&
                            business.description!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            business.description!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const Divider(height: AppSpacing.xxl),
                        if (showAddress) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: Text(
                                  business.address!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (showPhone) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: Text(
                                  business.phone!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                'Her randevu ${business.slotDurationMinutes} dakika',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Collapsible Working Hours Card
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isHoursExpanded = !_isHoursExpanded;
                            });
                          },
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(AppRadius.card),
                            bottom: Radius.circular(
                              _isHoursExpanded ? 0 : AppRadius.card,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Çalışma saatleri',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Icon(
                                  _isHoursExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isHoursExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: _buildSchedulesList(business.schedules),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Randevu Tarihi Section
                  const Text(
                    'Randevu tarihi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              formatTurkishDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Müsait Saatler Section
                  const Text(
                    'Müsait saatler',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                          icon: Icons.access_time_outlined,
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
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.s,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    _formatTime(slot.startTime),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: businessAsync.whenOrNull(
        data: (business) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
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
                child: const Text(
                  'Devam Et',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulesList(List<BusinessSchedule> schedules) {
    final days = {
      1: 'Pazartesi',
      2: 'Salı',
      3: 'Çarşamba',
      4: 'Perşembe',
      5: 'Cuma',
      6: 'Cumartesi',
      7: 'Pazar',
    };

    final children = <Widget>[];

    for (int i = 1; i <= 7; i++) {
      final dayName = days[i]!;
      final dayScheduleIndex = schedules.indexWhere((s) => s.dayOfWeek == i);
      final daySchedule = dayScheduleIndex != -1
          ? schedules[dayScheduleIndex]
          : null;

      String timeText;
      if (daySchedule == null || daySchedule.isClosed) {
        timeText = 'Kapalı';
      } else if (daySchedule.startTime != null && daySchedule.endTime != null) {
        timeText =
            '${_formatTime(daySchedule.startTime)} - ${_formatTime(daySchedule.endTime)}';
      } else {
        timeText = 'Kapalı';
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: timeText == 'Kapalı'
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: children);
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
