import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/core/theme/app_colors.dart';
import 'package:sirasende_mobile/core/theme/app_radius.dart';
import 'package:sirasende_mobile/core/theme/app_spacing.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/google_calendar_providers.dart';
import 'package:sirasende_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:sirasende_mobile/shared/widgets/app_card.dart';
import 'package:sirasende_mobile/shared/widgets/app_loading_indicator.dart';
import 'package:sirasende_mobile/shared/widgets/app_empty_state.dart';
import 'package:sirasende_mobile/shared/widgets/app_button.dart';
import 'package:sirasende_mobile/shared/widgets/app_text_field.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/admin_bottom_navigation.dart';

enum ProfileView { profile, editProfile, editSchedules }

class AdminProfileScreen extends ConsumerStatefulWidget {
  final ProfileView initialView;

  const AdminProfileScreen({super.key, this.initialView = ProfileView.profile});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late ProfileView _currentView;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _slotDuration;

  bool _initialized = false;
  List<BusinessSchedule>? _localSchedules;
  Map<int, String> _scheduleErrors = {};
  bool _isConnectingCalendar = false;

  final turkishDays = const [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialView;
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initializeValues(Business business) {
    if (_initialized) return;
    _nameController.text = business.name;
    _descriptionController.text = business.description ?? '';
    _phoneController.text = business.phone ?? '';
    _addressController.text = business.address ?? '';
    _slotDuration = business.slotDurationMinutes;

    if (business.workingStartTime != null) {
      final parts = business.workingStartTime!.split(':');
      if (parts.length >= 2) {
        _startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
    if (business.workingEndTime != null) {
      final parts = business.workingEndTime!.split(':');
      if (parts.length >= 2) {
        _endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    if (business.schedules.length == 7) {
      _localSchedules = List<BusinessSchedule>.from(business.schedules);
    } else {
      final defaultStart = business.workingStartTime ?? '09:00:00';
      final defaultEnd = business.workingEndTime ?? '18:00:00';
      _localSchedules = List.generate(7, (index) {
        return BusinessSchedule(
          dayOfWeek: index,
          startTime: defaultStart,
          endTime: defaultEnd,
          isClosed: false,
        );
      });
    }

    _initialized = true;
  }

  String _timeOfDayToString(TimeOfDay time) {
    final hourStr = time.hour.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr:00';
  }

  bool _validateSchedules() {
    setState(() {
      _scheduleErrors = {};
    });

    if (_localSchedules == null || _localSchedules!.length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Haftalık program tam olarak 7 gün içermelidir.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    bool isValid = true;
    for (int i = 0; i < _localSchedules!.length; i++) {
      final sched = _localSchedules![i];
      if (!sched.isClosed) {
        if (sched.startTime == null || sched.endTime == null) {
          setState(() {
            _scheduleErrors[i] = 'Açılış ve kapanış saatleri zorunludur.';
          });
          isValid = false;
          continue;
        }
        final start = _parseTimeString(sched.startTime);
        final end = _parseTimeString(sched.endTime);
        if (start != null && end != null) {
          final startMinutes = start.hour * 60 + start.minute;
          final endMinutes = end.hour * 60 + end.minute;
          if (endMinutes <= startMinutes) {
            setState(() {
              _scheduleErrors[i] =
                  '${turkishDays[sched.dayOfWeek]} günü kapanış saati açılıştan sonra olmalıdır.';
            });
            isValid = false;
          }
        }
      }
    }
    return isValid;
  }

  String _formatTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  String _timeOfDayToBackendString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  void _toggleDay(int index, bool isOpen) {
    if (_localSchedules == null) return;
    setState(() {
      final sched = _localSchedules![index];
      final defaultStart = _startTime != null
          ? _timeOfDayToBackendString(_startTime!)
          : '09:00:00';
      final defaultEnd = _endTime != null
          ? _timeOfDayToBackendString(_endTime!)
          : '18:00:00';

      _localSchedules![index] = sched.copyWith(
        isClosed: !isOpen,
        startTime: isOpen ? (sched.startTime ?? defaultStart) : sched.startTime,
        endTime: isOpen ? (sched.endTime ?? defaultEnd) : sched.endTime,
      );
      _scheduleErrors.remove(index);
    });
  }

  Future<void> _selectDayStartTime(BuildContext context, int index) async {
    final sched = _localSchedules![index];
    final parsed =
        _parseTimeString(sched.startTime) ??
        const TimeOfDay(hour: 9, minute: 0);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: parsed,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _localSchedules![index] = sched.copyWith(
          startTime: _timeOfDayToBackendString(picked),
        );
        _scheduleErrors.remove(index);
      });
    }
  }

  Future<void> _selectDayEndTime(BuildContext context, int index) async {
    final sched = _localSchedules![index];
    final parsed =
        _parseTimeString(sched.endTime) ?? const TimeOfDay(hour: 18, minute: 0);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: parsed,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _localSchedules![index] = sched.copyWith(
          endTime: _timeOfDayToBackendString(picked),
        );
        _scheduleErrors.remove(index);
      });
    }
  }

  void _submitProfileChanges() {
    if (!_formKey.currentState!.validate()) return;

    final startStr = _startTime != null
        ? _timeOfDayToString(_startTime!)
        : null;
    final endStr = _endTime != null ? _timeOfDayToString(_endTime!) : null;

    final schedulesPayload = _localSchedules?.map((sched) {
      if (sched.isClosed) {
        return BusinessSchedule(
          dayOfWeek: sched.dayOfWeek,
          isClosed: true,
          startTime: null,
          endTime: null,
        );
      } else {
        return sched;
      }
    }).toList();

    ref
        .read(adminBusinessUpdateControllerProvider.notifier)
        .updateBusiness(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          workingStartTime: startStr,
          workingEndTime: endStr,
          slotDurationMinutes: _slotDuration,
          schedules: schedulesPayload,
          onSuccess: () {
            if (mounted) {
              setState(() {
                _initialized = false;
                _currentView = ProfileView.profile;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('İşletme bilgileri güncellendi.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          onError: (message) {
            if (mounted) {
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

  void _submitSchedulesChanges() {
    if (!_validateSchedules()) return;

    final startStr = _startTime != null
        ? _timeOfDayToString(_startTime!)
        : null;
    final endStr = _endTime != null ? _timeOfDayToString(_endTime!) : null;

    final schedulesPayload = _localSchedules?.map((sched) {
      if (sched.isClosed) {
        return BusinessSchedule(
          dayOfWeek: sched.dayOfWeek,
          isClosed: true,
          startTime: null,
          endTime: null,
        );
      } else {
        return sched;
      }
    }).toList();

    ref
        .read(adminBusinessUpdateControllerProvider.notifier)
        .updateBusiness(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          workingStartTime: startStr,
          workingEndTime: endStr,
          slotDurationMinutes: _slotDuration,
          schedules: schedulesPayload,
          onSuccess: () {
            if (mounted) {
              setState(() {
                _initialized = false;
                _currentView = ProfileView.profile;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Çalışma saatleri kaydedildi.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          onError: (message) {
            if (mounted) {
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

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _currentView = ProfileView.profile;
      });
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  String _mapErrorMessage(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Profil bilgileri sunucudan yüklenemedi.';
  }

  Widget _buildReadOnlyProfile(Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Business Header Info
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(
                      Icons.storefront,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (business.description != null &&
                            business.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            business.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      business.address ?? 'Adres belirtilmemiş',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      business.phone ?? 'Telefon belirtilmemiş',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Randevu Süresi: ${business.slotDurationMinutes} dakika',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Profili Düzenle',
                  isOutlined: true,
                  onPressed: () {
                    setState(() {
                      _currentView = ProfileView.editProfile;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 2. Schedules Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Çalışma Saatleri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentView = ProfileView.editSchedules;
                });
              },
              child: const Text('Saatleri Düzenle'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        AppCard(
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: List.generate(7, (index) {
              final sortedSched = business.schedules.length == 7
                  ? (List<BusinessSchedule>.from(business.schedules)
                      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek)))
                  : List.generate(7, (index) {
                      return BusinessSchedule(
                        dayOfWeek: index,
                        startTime: business.workingStartTime ?? '09:00:00',
                        endTime: business.workingEndTime ?? '18:00:00',
                        isClosed: false,
                      );
                    });

              final sched = sortedSched[index];
              final dayName = turkishDays[index];

              String scheduleText = 'Çalışma programı belirtilmemiş';
              if (sched.isClosed) {
                scheduleText = 'Kapalı';
              } else if (sched.startTime != null && sched.endTime != null) {
                scheduleText =
                    '${_formatTimeString(sched.startTime!)} - ${_formatTimeString(sched.endTime!)}';
              }

              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      dayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      scheduleText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sched.isClosed
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: sched.isClosed
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 3. Google Calendar Card Section
        const Text(
          'Google Takvim Entegrasyonu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildGoogleCalendarSection(),
        const SizedBox(height: AppSpacing.xl),

        // 4. Oturum / Logout Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hesap Ayarları',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yönetici Oturumu',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Divider(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Çıkış Yap',
                  isOutlined: true,
                  onPressed: _confirmLogout,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildEditProfileForm(bool isSaving) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'İşletme Adı',
                  hint: 'İşletmenizin adını girin',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'İşletme adı boş olamaz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Açıklama',
                  hint: 'Açıklama yazısı (max 500)',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 500) {
                      return 'Açıklama en fazla 500 karakter olabilir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Telefon',
                  hint: 'Telefon numaranızı girin',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Telefon numarası boş olamaz.';
                    }
                    final phoneRegex = RegExp(r'^\+?[0-9\s\-]{10,20}$');
                    if (!phoneRegex.hasMatch(value.trim())) {
                      return 'Geçerli bir telefon numarası giriniz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppTextField(
                  label: 'Adres',
                  hint: 'Adres bilgilerini girin',
                  controller: _addressController,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Adres alanı boş olamaz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<int>(
                  value: _slotDuration,
                  decoration: const InputDecoration(
                    labelText: 'Randevu Süresi (Dakika)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer),
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 Dakika')),
                    DropdownMenuItem(value: 45, child: Text('45 Dakika')),
                    DropdownMenuItem(value: 60, child: Text('60 Dakika')),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _slotDuration = value;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Randevu süresi seçimi zorunludur.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
            isLoading: isSaving,
            onPressed: isSaving ? null : _submitProfileChanges,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildEditSchedulesForm(bool isSaving) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Haftalık Çalışma Programı',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Müşteriler yalnızca açık olduğunuz gün ve saatler için randevu alabilir.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (_localSchedules != null)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            itemBuilder: (context, index) {
              final sched = _localSchedules![index];
              final isOpen = !sched.isClosed;
              final dayName = turkishDays[sched.dayOfWeek];
              final errorMsg = _scheduleErrors[index];

              return AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              isOpen ? 'Açık' : 'Kapalı',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOpen ? AppColors.success : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isOpen,
                              onChanged: isSaving
                                  ? null
                                  : (val) => _toggleDay(index, val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isOpen) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => _selectDayStartTime(context, index),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Açılış Saati',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time, size: 16),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  sched.startTime != null
                                      ? _formatTimeString(sched.startTime!)
                                      : '--:--',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: isSaving
                                  ? null
                                  : () => _selectDayEndTime(context, index),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Kapanış Saati',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(
                                    Icons.access_time_filled,
                                    size: 16,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  sched.endTime != null
                                      ? _formatTimeString(sched.endTime!)
                                      : '--:--',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        errorMsg,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: isSaving ? 'Kaydediliyor...' : 'Çalışma Saatlerini Kaydet',
          isLoading: isSaving,
          onPressed: isSaving ? null : _submitSchedulesChanges,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessState = ref.watch(adminBusinessProvider);
    final updateState = ref.watch(adminBusinessUpdateControllerProvider);
    final isSaving = updateState.isLoading;

    // Calculate AppBar headers dynamically
    String appBarTitle = 'İşletme Profili';
    bool showBackButton = false;

    if (_currentView == ProfileView.editProfile) {
      appBarTitle = 'Profili Düzenle';
      showBackButton = true;
    } else if (_currentView == ProfileView.editSchedules) {
      appBarTitle = 'Çalışma Saatleri';
      showBackButton = true;
    }

    return PopScope(
      canPop: _currentView == ProfileView.profile,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _currentView = ProfileView.profile;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          automaticallyImplyLeading: false,
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            _currentView = ProfileView.profile;
                          });
                        },
                )
              : null,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: SafeArea(
          child: businessState.when(
            data: (business) {
              _initializeValues(business);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    if (_currentView == ProfileView.profile)
                      _buildReadOnlyProfile(business)
                    else if (_currentView == ProfileView.editProfile)
                      _buildEditProfileForm(isSaving)
                    else if (_currentView == ProfileView.editSchedules)
                      _buildEditSchedulesForm(isSaving),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: AppLoadingIndicator(message: 'Profil yükleniyor...'),
            ),
            error: (error, _) => AppEmptyState(
              title: 'Profil Yüklenemedi',
              message: _mapErrorMessage(error),
              icon: Icons.error_outline,
              actionLabel: 'Tekrar Dene',
              onAction: () {
                ref.invalidate(adminBusinessProvider);
              },
            ),
          ),
        ),
        bottomNavigationBar: _currentView == ProfileView.profile
            ? const AdminBottomNavigation(currentIndex: 2)
            : null,
      ),
    );
  }

  Widget _buildGoogleCalendarSection() {
    final statusAsync = ref.watch(googleCalendarStatusProvider);
    final controllerState = ref.watch(googleCalendarControllerProvider);
    final isLoading = controllerState.isLoading;

    return statusAsync.when(
      data: (status) {
        if (status.connected) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 8),
                    const Text(
                      'Google Takvim Bağlı',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (status.googleAccountEmail != null &&
                    status.googleAccountEmail!.isNotEmpty) ...[
                  Text(
                    'Bağlı Hesap: ${status.googleAccountEmail}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                const Text(
                  'Onaylanan randevular otomatik olarak takviminize eklenir.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Bağlantıyı Kaldır',
                    isOutlined: true,
                    isLoading: isLoading,
                    onPressed: isLoading
                        ? null
                        : _showDisconnectConfirmationDialog,
                  ),
                ),
              ],
            ),
          );
        } else {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Randevularınızı Google Takviminiz ile senkronize etmek için hesabınızı bağlayın.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Google Takvim\'i Bağla',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _connectGoogleCalendar,
                  ),
                ),
              ],
            ),
          );
        }
      },
      loading: () => const AppCard(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bağlantı durumu alınamadı.',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Tekrar Dene',
                isOutlined: true,
                onPressed: () {
                  ref.invalidate(googleCalendarStatusProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectGoogleCalendar() async {
    if (_isConnectingCalendar) return;
    setState(() {
      _isConnectingCalendar = true;
    });

    try {
      final controller = ref.read(googleCalendarControllerProvider.notifier);
      final authUrl = await controller.connect(
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bağlantı kurulamadı: $msg'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      );

      if (authUrl == null || authUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geçersiz veya boş bağlantı adresi.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final uri = Uri.tryParse(authUrl);
      if (uri == null || uri.scheme != 'https') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Yalnızca güvenli HTTPS bağlantı adresleri açılabilir.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      debugPrint('=== GOOGLE CALENDAR CONNECT ===');
      debugPrint('Received OAuth URL scheme: ${uri.scheme}, host: ${uri.host}');

      if (mounted) {
        try {
          // Diagnostic check only - does not block launching
          final canLaunch = await canLaunchUrl(uri);
          debugPrint('Diagnostic canLaunchUrl result: $canLaunch');

          debugPrint('Attempting direct launchUrl...');
          final success = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          debugPrint('launchUrl result success: $success');

          if (!success) {
            throw Exception('Tarayıcı üzerinden bağlantı adresi açılamadı.');
          }
        } catch (e, stackTrace) {
          debugPrint('Google Calendar Connect Launch Error: $e');
          debugPrint('Stacktrace: $stackTrace');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bağlantı adresi açılamadı: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
      debugPrint('===============================');
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingCalendar = false;
        });
      }
    }
  }

  Future<void> _showDisconnectConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Takvim Bağlantısını Kaldır'),
        content: const Text(
          'Yeni onaylanan randevular artık Google Takvim’e eklenmeyecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Bağlantıyı Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(googleCalendarControllerProvider.notifier)
          .disconnect(
            onSuccess: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Google Takvim bağlantısı kaldırıldı.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                ref.invalidate(googleCalendarStatusProvider);
              }
            },
            onError: (msg) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          );
    }
  }
}
