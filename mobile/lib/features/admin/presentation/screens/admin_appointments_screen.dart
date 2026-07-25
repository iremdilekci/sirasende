import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/theme/app_colors.dart';
import 'package:sirasende_mobile/core/theme/app_radius.dart';
import 'package:sirasende_mobile/core/theme/app_spacing.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:sirasende_mobile/shared/widgets/app_card.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import '../widgets/admin_bottom_navigation.dart';

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  DateTime? _selectedDate;
  String? _selectedStatus;

  // Local state to track which appointment IDs are currently executing an action
  final List<String> _executingAppointmentIds = [];
  // Local state to track which appointment IDs are executing Google Calendar Sync
  final List<String> _syncingAppointmentIds = [];

  final List<Map<String, String?>> _statusOptions = const [
    {'label': 'Tüm Durumlar', 'value': null},
    {'label': 'Beklemede', 'value': 'pending'},
    {'label': 'Onaylandı', 'value': 'confirmed'},
    {'label': 'Tamamlandı', 'value': 'completed'},
    {'label': 'İptal Edildi', 'value': 'cancelled'},
  ];

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _selectedStatus = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      helpText: 'Tarih Seçin',
      confirmText: 'Seç',
      cancelText: 'İptal',
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
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandı';
      case 'cancelled':
        return 'İptal Edildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSyncStatus(Appointment appointment) {
    final status = appointment.calendarSyncStatus;
    if (status == 'not_connected') return const SizedBox.shrink();

    Color chipColor;
    IconData icon;
    String text;
    bool showRetry = false;

    switch (status) {
      case 'synced':
        chipColor = AppColors.success;
        icon = Icons.check_circle_outline;
        text = 'Google Takvim\'e eklendi';
        break;
      case 'failed':
        chipColor = AppColors.error;
        icon = Icons.sync_problem;
        text = 'Senkronizasyon başarısız';
        showRetry = true;
        break;
      case 'deleted':
        chipColor = AppColors.textSecondary;
        icon = Icons.sync_disabled;
        text = 'Google Takvim etkinliği kaldırıldı';
        break;
      case 'pending':
        chipColor = AppColors.warning;
        icon = Icons.sync;
        text = 'Senkronizasyon bekliyor';
        break;
      default:
        return const SizedBox.shrink();
    }

    final isSyncing = _syncingAppointmentIds.contains(appointment.id);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: chipColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(width: AppSpacing.s),
            TextButton.icon(
              onPressed: isSyncing
                  ? null
                  : () => _executeManualSync(appointment.id),
              icon: isSyncing
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.error,
                        ),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 12),
              label: const Text('Tekrar Dene', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                foregroundColor: chipColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeManualSync(String appointmentId) async {
    setState(() {
      _syncingAppointmentIds.add(appointmentId);
    });

    await ref
        .read(googleCalendarSyncControllerProvider.notifier)
        .syncAppointment(
          id: appointmentId,
          onSuccess: () {
            if (mounted) {
              setState(() {
                _syncingAppointmentIds.remove(appointmentId);
              });
              ref.invalidate(adminAppointmentsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Google Takvim senkronizasyonu tamamlandı.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          onError: (msg) {
            if (mounted) {
              setState(() {
                _syncingAppointmentIds.remove(appointmentId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Google Takvim senkronizasyonu başarısız oldu: $msg',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        );
  }

  Future<void> _confirmAction({
    required String appointmentId,
    required String actionName,
    required String targetStatus,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: targetStatus == 'cancelled'
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _executeStatusUpdate(appointmentId, targetStatus);
    }
  }

  Future<void> _executeStatusUpdate(
    String appointmentId,
    String targetStatus,
  ) async {
    setState(() {
      _executingAppointmentIds.add(appointmentId);
    });

    await ref
        .read(adminAppointmentActionControllerProvider.notifier)
        .updateStatus(
          id: appointmentId,
          status: targetStatus,
          onSuccess: () {
            if (mounted) {
              setState(() {
                _executingAppointmentIds.remove(appointmentId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Randevu durumu başarıyla güncellendi.'),
                  backgroundColor: AppColors.success,
                ),
              );
              ref.invalidate(adminAppointmentsProvider);
            }
          },
          onError: (message) {
            if (mounted) {
              setState(() {
                _executingAppointmentIds.remove(appointmentId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
        );
  }

  String _mapErrorMessage(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Randevular yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.';
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    final isExecuting = _executingAppointmentIds.contains(appointment.id);
    final timeText =
        "${appointment.startTime.substring(0, 5)} - ${appointment.endTime.substring(0, 5)}";
    final turkishDate = appointment.appointmentDate;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Slot & Status Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(appointment.status),
            ],
          ),
          const Divider(height: AppSpacing.lg),

          // Customer details row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  appointment.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          // Phone details row
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                appointment.customerPhone,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          // Date row
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                turkishDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Note row (optional)
          if (appointment.customerNote != null &&
              appointment.customerNote!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Not:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            appointment.customerNote!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Google Calendar Row (if connect status is not default/none)
          _buildCalendarSyncStatus(appointment),

          // Action buttons row (only for pending & confirmed statuses)
          if (!isExecuting &&
              (appointment.status == 'pending' ||
                  appointment.status == 'confirmed')) ...[
            const Divider(height: AppSpacing.xl),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (appointment.status == 'pending') ...[
                  // Cancel button
                  OutlinedButton.icon(
                    onPressed: () => _confirmAction(
                      appointmentId: appointment.id,
                      actionName: 'İptal',
                      targetStatus: 'cancelled',
                      title: 'İptal Onayı',
                      message: 'Bu randevuyu iptal etmek istiyor musunuz?',
                      confirmLabel: 'Evet, Devam Et',
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'İptal Et',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                  // Approve button
                  FilledButton.icon(
                    onPressed: () => _confirmAction(
                      appointmentId: appointment.id,
                      actionName: 'Onayla',
                      targetStatus: 'confirmed',
                      title: 'Onayla Onayı',
                      message: 'Bu randevuyu onaylamak istiyor musunuz?',
                      confirmLabel: 'Evet, Devam Et',
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Onayla', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                ] else if (appointment.status == 'confirmed') ...[
                  // Cancel button
                  OutlinedButton.icon(
                    onPressed: () => _confirmAction(
                      appointmentId: appointment.id,
                      actionName: 'İptal',
                      targetStatus: 'cancelled',
                      title: 'İptal Onayı',
                      message: 'Bu randevuyu iptal etmek istiyor musunuz?',
                      confirmLabel: 'Evet, Devam Et',
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'İptal Et',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                  // Complete button
                  FilledButton.icon(
                    onPressed: () => _confirmAction(
                      appointmentId: appointment.id,
                      actionName: 'Tamamla',
                      targetStatus: 'completed',
                      title: 'Tamamla Onayı',
                      message: 'Bu randevuyu tamamlamak istiyor musunuz?',
                      confirmLabel: 'Evet, Devam Et',
                    ),
                    icon: const Icon(Icons.done, size: 14),
                    label: const Text(
                      'Tamamla',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ],
            ),
          ] else if (isExecuting) ...[
            const Divider(height: AppSpacing.xl),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _selectedDate != null ? _formatDate(_selectedDate!) : null;
    final params = AdminAppointmentsParams(
      date: dateStr,
      status: _selectedStatus,
    );

    final appointmentsAsync = ref.watch(adminAppointmentsProvider(params));
    final isActionLoading = ref
        .watch(adminAppointmentActionControllerProvider)
        .isLoading;

    final hasActiveFilter = _selectedDate != null || _selectedStatus != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Randevularım',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        automaticallyImplyLeading: false, // Prevent physical back navigation
        actions: [
          IconButton(
            tooltip: 'Randevuları yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(adminAppointmentsProvider);
            },
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filters section container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  // Horizontal Status Filters Scroll
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: _statusOptions.map((opt) {
                        final isSelected = _selectedStatus == opt['value'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(opt['label']!),
                            selected: isSelected,
                            onSelected: isActionLoading
                                ? null
                                : (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedStatus = opt['value'];
                                      });
                                    }
                                  },
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),

                  // Date Picker Trigger Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isActionLoading
                                ? null
                                : () => _selectDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Tarih Seçin',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? _formatDate(_selectedDate!)
                                    : 'Tarih Seç',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        if (hasActiveFilter) ...[
                          const SizedBox(width: AppSpacing.md),
                          TextButton(
                            onPressed: isActionLoading ? null : _clearFilters,
                            child: const Text(
                              'Temizle',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Appointments List View
            Expanded(
              child: appointmentsAsync.when(
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return const AppEmptyState(
                      title: 'Henüz randevu bulunmuyor',
                      message:
                          'Seçilen filtrelere uygun gelen bir randevu bulunmamaktadır.',
                      icon: Icons.calendar_today_outlined,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      return _buildAppointmentCard(appointments[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppEmptyState(
                  title: 'Randevular Yüklenemedi',
                  message: _mapErrorMessage(error),
                  icon: Icons.error_outline,
                  actionLabel: 'Tekrar Dene',
                  onAction: () {
                    ref.invalidate(adminAppointmentsProvider);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavigation(currentIndex: 1),
    );
  }
}
