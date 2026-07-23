import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
import 'package:sirasende_mobile/features/business/domain/models/business_schedule.dart';
import 'package:sirasende_mobile/features/business/presentation/providers/business_providers.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _slotDuration;

  bool _initialized = false;
  String? _timeError;
  List<BusinessSchedule>? _localSchedules;

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

  bool _validateTimes() {
    if (_startTime == null || _endTime == null) return true;
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    return endMinutes > startMinutes;
  }

  bool _validateSchedules() {
    if (_localSchedules == null || _localSchedules!.length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Haftalık program tam olarak 7 gün içermelidir.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    for (final sched in _localSchedules!) {
      if (!sched.isClosed) {
        if (sched.startTime == null || sched.endTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${turkishDays[sched.dayOfWeek]} günü için açılış ve kapanış saatleri zorunludur.'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        final start = _parseTimeString(sched.startTime);
        final end = _parseTimeString(sched.endTime);
        if (start != null && end != null) {
          final startMinutes = start.hour * 60 + start.minute;
          final endMinutes = end.hour * 60 + end.minute;
          if (endMinutes <= startMinutes) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${turkishDays[sched.dayOfWeek]} günü kapanış saati açılıştan sonra olmalıdır.'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }
      }
    }
    return true;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _timeError = null;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _timeError = null;
      });
    }
  }

  void _toggleDay(int index, bool isOpen) {
    if (_localSchedules == null) return;
    setState(() {
      final sched = _localSchedules![index];
      final defaultStart = _startTime != null ? _timeOfDayToBackendString(_startTime!) : '09:00:00';
      final defaultEnd = _endTime != null ? _timeOfDayToBackendString(_endTime!) : '18:00:00';

      _localSchedules![index] = sched.copyWith(
        isClosed: !isOpen,
        startTime: isOpen ? (sched.startTime ?? defaultStart) : sched.startTime,
        endTime: isOpen ? (sched.endTime ?? defaultEnd) : sched.endTime,
      );
    });
  }

  Future<void> _selectDayStartTime(BuildContext context, int index) async {
    final sched = _localSchedules![index];
    final parsed = _parseTimeString(sched.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
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
      });
    }
  }

  Future<void> _selectDayEndTime(BuildContext context, int index) async {
    final sched = _localSchedules![index];
    final parsed = _parseTimeString(sched.endTime) ?? const TimeOfDay(hour: 18, minute: 0);
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
      });
    }
  }

  String _mapErrorMessage(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Profil bilgileri yüklenirken bir hata oluştu. Lütfen tekrar deneyin.';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_validateTimes()) {
      setState(() {
        _timeError = 'Kapanış saati, açılış saatinden sonra olmalıdır.';
      });
      return;
    }

    if (!_validateSchedules()) {
      return;
    }

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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil bilgileri başarıyla güncellendi.'),
                  backgroundColor: Colors.green,
                ),
              );
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
    final businessState = ref.watch(adminBusinessProvider);
    final updateState = ref.watch(adminBusinessUpdateControllerProvider);
    final isSaving = updateState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Yönetimi')),
      body: SafeArea(
        child: businessState.when(
          data: (business) {
            _initializeValues(business);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İşletme Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Business Name
                    TextFormField(
                      controller: _nameController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'İşletme Adı',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'İşletme adı boş olamaz.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !isSaving,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 500) {
                          return 'Açıklama en fazla 500 karakter olabilir.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
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
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      enabled: !isSaving,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Adres',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Adres boş olamaz.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Varsayılan Çalışma Saatleri (Fallback)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Working Hours Picker
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isSaving
                                ? null
                                : () => _selectStartTime(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Açılış Saati',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(
                                _startTime != null
                                    ? _formatTime(_startTime!)
                                    : '--:--',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: isSaving
                                ? null
                                : () => _selectEndTime(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Kapanış Saati',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time_filled),
                              ),
                              child: Text(
                                _endTime != null
                                    ? _formatTime(_endTime!)
                                    : '--:--',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_timeError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _timeError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Slot Duration Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _slotDuration,
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
                    const SizedBox(height: 24),

                    Text(
                      'Haftalık Çalışma Programı',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_localSchedules != null)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final sched = _localSchedules![index];
                          final isOpen = !sched.isClosed;
                          final dayName = turkishDays[sched.dayOfWeek];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dayName,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            isOpen ? 'Açık' : 'Kapalı',
                                            style: TextStyle(
                                              color: isOpen ? Colors.green : Colors.grey,
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: (!isOpen || isSaving)
                                              ? null
                                              : () => _selectDayStartTime(context, index),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Opacity(
                                            opacity: isOpen ? 1.0 : 0.5,
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'Açılış Saati',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(Icons.access_time),
                                              ),
                                              child: Text(
                                                sched.startTime != null
                                                    ? _formatTimeString(sched.startTime!)
                                                    : '--:--',
                                                style: Theme.of(context).textTheme.bodyLarge,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: InkWell(
                                          onTap: (!isOpen || isSaving)
                                              ? null
                                              : () => _selectDayEndTime(context, index),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Opacity(
                                            opacity: isOpen ? 1.0 : 0.5,
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'Kapanış Saati',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(Icons.access_time_filled),
                                              ),
                                              child: Text(
                                                sched.endTime != null
                                                    ? _formatTimeString(sched.endTime!)
                                                    : '--:--',
                                                style: Theme.of(context).textTheme.bodyLarge,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: isSaving ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Kaydet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _mapErrorMessage(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(adminBusinessProvider);
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
    );
  }
}
