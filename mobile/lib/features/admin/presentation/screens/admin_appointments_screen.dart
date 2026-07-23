import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/appointment/presentation/providers/appointment_providers.dart';

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

  final List<Map<String, String?>> _statusOptions = const [
    {'label': 'Tüm Durumlar', 'value': null},
    {'label': 'Beklemede', 'value': 'pending'},
    {'label': 'Onaylandı', 'value': 'confirmed'},
    {'label': 'İptal Edildi', 'value': 'cancelled'},
    {'label': 'Tamamlandı', 'value': 'completed'},
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
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'completed':
        return Colors.green.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
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
        return 'Bilinmiyor';
    }
  }

  String _mapErrorMessage(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Randevular yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.';
  }

  Future<void> _confirmAction({
    required String appointmentId,
    required String actionName,
    required String targetStatus,
    required String message,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionName Onayı'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Devam Et'),
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
    await ref
        .read(adminAppointmentActionControllerProvider.notifier)
        .updateStatus(
          id: appointmentId,
          status: targetStatus,
          onSuccess: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Randevu durumu başarıyla güncellendi.'),
                  backgroundColor: Colors.green,
                ),
              );
              ref.invalidate(adminAppointmentsProvider);
            }
          },
          onError: (message) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red),
              );
            }
          },
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
      appBar: AppBar(
        title: const Text('Randevularım'),
        actions: [
          if (hasActiveFilter)
            TextButton.icon(
              onPressed: isActionLoading ? null : _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Temizle'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filters panel
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Date Filter
                    Expanded(
                      child: InkWell(
                        onTap: isActionLoading
                            ? null
                            : () => _selectDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tarih',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDate != null
                                      ? _formatDate(_selectedDate!)
                                      : 'Tarih Seçin',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedDate != null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Durum',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: _statusOptions.map((opt) {
                          return DropdownMenuItem<String?>(
                            value: opt['value'],
                            child: Text(
                              opt['label']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: isActionLoading
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedStatus = val;
                                });
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isActionLoading) const LinearProgressIndicator(),

            // Appointments List area
            Expanded(
              child: appointmentsAsync.when(
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(adminAppointmentsProvider(params).future),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.5,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withAlpha(128),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz randevu bulunmuyor',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Seçilen filtrelere uygun gelen bir randevu bulunmamaktadır.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(adminAppointmentsProvider(params).future),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];
                        final statusColor = _getStatusColor(
                          appointment.status,
                          context,
                        );

                        final hasActions =
                            appointment.status == 'pending' ||
                            appointment.status == 'confirmed';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        appointment.customerName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(26),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getStatusLabel(appointment.status),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          appointment.appointmentDate,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${appointment.startTime} - ${appointment.endTime}",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (appointment.customerNote != null &&
                                    appointment.customerNote!.isNotEmpty) ...[
                                  const Divider(height: 24),
                                  Text(
                                    'Not:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    appointment.customerNote!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                if (hasActions) ...[
                                  const Divider(height: 24),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (appointment.status == 'pending') ...[
                                        FilledButton.icon(
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _confirmAction(
                                                  appointmentId: appointment.id,
                                                  actionName: 'Onayla',
                                                  targetStatus: 'confirmed',
                                                  message:
                                                      'Bu randevuyu onaylamak istiyor musunuz?',
                                                ),
                                          icon: const Icon(
                                            Icons.check,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Onayla',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _confirmAction(
                                                  appointmentId: appointment.id,
                                                  actionName: 'İptal Et',
                                                  targetStatus: 'cancelled',
                                                  message:
                                                      'Bu randevuyu iptal etmek istiyor musunuz?',
                                                ),
                                          icon: const Icon(
                                            Icons.cancel,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'İptal Et',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade700,
                                            side: BorderSide(
                                              color: Colors.red.shade700,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ] else if (appointment.status ==
                                          'confirmed') ...[
                                        FilledButton.icon(
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _confirmAction(
                                                  appointmentId: appointment.id,
                                                  actionName: 'Tamamla',
                                                  targetStatus: 'completed',
                                                  message:
                                                      'Bu randevuyu tamamlandı olarak işaretlemek istiyor musunuz?',
                                                ),
                                          icon: const Icon(
                                            Icons.task_alt,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Tamamla',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _confirmAction(
                                                  appointmentId: appointment.id,
                                                  actionName: 'İptal Et',
                                                  targetStatus: 'cancelled',
                                                  message:
                                                      'Bu randevuyu iptal etmek istiyor musunuz?',
                                                ),
                                          icon: const Icon(
                                            Icons.cancel,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'İptal Et',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade700,
                                            side: BorderSide(
                                              color: Colors.red.shade700,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(adminAppointmentsProvider(params).future),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Randevular Yüklenemedi',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mapErrorMessage(error),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              ref.invalidate(adminAppointmentsProvider(params));
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
