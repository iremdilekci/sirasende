import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../appointment/data/models/appointment_create_request.dart';
import '../../../appointment/domain/models/appointment_draft.dart';
import '../models/appointment_success_args.dart';
import '../providers/appointment_providers.dart';
import '../models/appointment_form_args.dart';
import '../../../business/presentation/helpers/datetime_helpers.dart';
import '../../../business/presentation/providers/business_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';

class AppointmentFormScreen extends ConsumerStatefulWidget {
  final AppointmentFormArgs args;
  final ValueChanged<AppointmentDraft>? onValidSubmit;

  const AppointmentFormScreen({
    super.key,
    required this.args,
    this.onValidSubmit,
  });

  @override
  ConsumerState<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int _computeDurationMinutes(String startStr, String endStr) {
    try {
      final startParts = startStr.split(':').map(int.parse).toList();
      final endParts = endStr.split(':').map(int.parse).toList();
      final startMin = startParts[0] * 60 + startParts[1];
      final endMin = endParts[0] * 60 + endParts[1];
      final diff = endMin - startMin;
      return diff > 0 ? diff : 30;
    } catch (_) {
      return 30;
    }
  }

  String _formatTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final draft = AppointmentDraft(
      businessSlug: widget.args.businessSlug,
      businessName: widget.args.businessName,
      appointmentDate: widget.args.date,
      startTime: widget.args.startTime,
      endTime: widget.args.endTime,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    widget.onValidSubmit?.call(draft);

    final request = AppointmentCreateRequest.fromDraft(draft);

    await ref
        .read(appointmentControllerProvider.notifier)
        .bookAppointment(
          businessSlug: widget.args.businessSlug,
          request: request,
          onSuccess: (appointment) {
            if (mounted) {
              context.goNamed(
                RouteNames.customerAppointmentSuccess,
                extra: AppointmentSuccessArgs(
                  businessName: widget.args.businessName,
                  appointmentDate: appointment.appointmentDate,
                  startTime: appointment.startTime,
                  endTime: appointment.endTime,
                  status: appointment.status,
                ),
              );
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(appointmentControllerProvider);
    final isLoading = bookingState.isLoading;

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(widget.args.date);
    } catch (_) {}
    final dateText = parsedDate != null
        ? formatTurkishDate(parsedDate)
        : widget.args.date;

    AppException? appError;
    if (bookingState.hasError && bookingState.error is AppException) {
      appError = bookingState.error as AppException;
    }

    final isConflict = appError?.code == 'CONFLICT';
    final duration = _computeDurationMinutes(
      widget.args.startTime,
      widget.args.endTime,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Randevu Bilgileri',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error card if any
                if (appError != null) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    color: const Color(0xFFFFEBEE), // light red
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  isConflict
                                      ? 'Bu saat artık müsait değil'
                                      : 'İşlem Başarısız',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Text(
                            appError.message,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          if (isConflict) ...[
                            const SizedBox(height: AppSpacing.lg),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                label: 'Başka Saat Seç',
                                onPressed: () {
                                  ref.invalidate(
                                    businessSlotsProvider(
                                      BusinessSlotsParams(
                                        slug: widget.args.businessSlug,
                                        date: widget.args.date,
                                      ),
                                    ),
                                  );
                                  context.pop();
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // Selection Summary Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.args.businessName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Divider(height: AppSpacing.xxl),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            dateText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_formatTime(widget.args.startTime)} – ${_formatTime(widget.args.endTime)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Text(
                                  '$duration dk',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                const Text(
                  'Müşteri Bilgileri',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Name Field
                AppTextField(
                  label: 'Ad Soyad',
                  hint: 'Adınızı ve soyadınızı girin',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ad soyad alanı zorunludur.';
                    }
                    final cleanVal = value.trim();
                    if (cleanVal.length < 2) {
                      return 'Ad soyad en az 2 karakter olmalıdır.';
                    }
                    if (cleanVal.length > 200) {
                      return 'Ad soyad en fazla 200 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Phone Field
                AppTextField(
                  label: 'Telefon Numarası',
                  hint: '05xx xxx xx xx',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Telefon numarası alanı zorunludur.';
                    }
                    final cleanVal = value.trim();
                    if (cleanVal.length < 5) {
                      return 'Telefon numarası en az 5 karakter olmalıdır.';
                    }
                    if (cleanVal.length > 30) {
                      return 'Telefon numarası en fazla 30 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Note Field
                AppTextField(
                  label: 'Not (İsteğe Bağlı)',
                  hint:
                      'Eklemek istediğiniz bir not varsa buraya yazabilirsiniz...',
                  controller: _noteController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 1000) {
                      return 'Not en fazla 1000 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Randevu oluşturulduktan sonra işletme tarafından onaylanacaktır.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary.withRed(30).withBlue(150),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Submit Button
                AppButton(
                  label: isLoading
                      ? 'Randevu oluşturuluyor...'
                      : 'Randevuyu Oluştur',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
