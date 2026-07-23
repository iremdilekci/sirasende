import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sirasende_mobile/core/errors/app_exception.dart';
import 'package:sirasende_mobile/features/business/domain/models/business.dart';
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

    final startStr = _startTime != null
        ? _timeOfDayToString(_startTime!)
        : null;
    final endStr = _endTime != null ? _timeOfDayToString(_endTime!) : null;

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
                      'Çalışma Ayarları',
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
