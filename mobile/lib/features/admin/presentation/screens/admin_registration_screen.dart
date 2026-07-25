import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/data/models/registration_request.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_button.dart';

class AdminRegistrationScreen extends ConsumerStatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  ConsumerState<AdminRegistrationScreen> createState() =>
      _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState
    extends ConsumerState<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  int _selectedSlotDuration = 30;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final request = RegistrationRequest(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      businessName: _businessNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      description: _descriptionController.text.trim(),
      slotDurationMinutes: _selectedSlotDuration,
    );

    try {
      await ref
          .read(adminRegistrationControllerProvider.notifier)
          .register(
            request: request,
            onSuccess: (response) {
              if (mounted) {
                // Navigate to success screen and clear stack
                context.goNamed(
                  RouteNames.adminRegisterSuccess,
                  extra: response.email,
                );
              }
            },
            onFailure: (errorMsg) {
              if (mounted) {
                _showErrorSnackBar(errorMsg);
              }
            },
          );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    String cleanMessage = message;
    if (message.contains('AppException')) {
      final colonIndex = message.indexOf(':');
      if (colonIndex != -1) {
        cleanMessage = message.substring(colonIndex + 1).trim();
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanMessage),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = ref.watch(adminRegistrationControllerProvider);
    final isLoading = registrationState.isLoading || _isSubmitting;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              const Color(0xFF3B2FBF),
              AppColors.background,
            ],
            stops: const [0.0, 0.3, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar with Back Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.s,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: isLoading ? null : () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'İşletme Kaydı',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Scroll Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'İşletme Bilgileri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Divider(height: AppSpacing.lg),

                          // Business Name
                          AppTextField(
                            controller: _businessNameController,
                            label: 'İşletme Adı *',
                            hint: 'Örn. Salon Elite',
                            prefixIcon: Icons.storefront,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'İşletme adı zorunludur.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Phone
                          AppTextField(
                            controller: _phoneController,
                            label: 'Telefon Numarası',
                            hint: 'Örn. 05551234567',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  value.length > 30) {
                                return 'Telefon numarası en fazla 30 karakter olmalıdır.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Address
                          AppTextField(
                            controller: _addressController,
                            label: 'Adres',
                            hint: 'İşletme adresi...',
                            prefixIcon: Icons.location_on,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  value.length > 500) {
                                return 'Adres en fazla 500 karakter olmalıdır.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Description
                          AppTextField(
                            controller: _descriptionController,
                            label: 'Açıklama',
                            hint: 'İşletme hakkında kısa bilgi...',
                            prefixIcon: Icons.description,
                            maxLines: 3,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Slot Duration Dropdown
                          const Text(
                            'Randevu Süresi (Dakika) *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<int>(
                            value: _selectedSlotDuration,
                            items: const [
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 Dakika'),
                              ),
                              DropdownMenuItem(
                                value: 45,
                                child: Text('45 Dakika'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('60 Dakika'),
                              ),
                            ],
                            onChanged: isLoading
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSlotDuration = val;
                                      });
                                    }
                                  },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.s,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          const Text(
                            'Hesap Bilgileri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Divider(height: AppSpacing.lg),

                          // Username
                          AppTextField(
                            controller: _usernameController,
                            label: 'Kullanıcı Adı *',
                            hint: 'kullanici_adi',
                            prefixIcon: Icons.person,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kullanıcı adı zorunludur.';
                              }
                              final normalized = value.trim();
                              if (normalized.length < 3 ||
                                  normalized.length > 30) {
                                return 'Kullanıcı adı 3-30 karakter olmalıdır.';
                              }
                              final regex = RegExp(r'^[a-z0-9_]+$');
                              if (!regex.hasMatch(normalized)) {
                                return 'Yalnızca küçük harf, rakam ve alt çizgi kullanın.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Email
                          AppTextField(
                            controller: _emailController,
                            label: 'E-posta Adresi *',
                            hint: 'eposta@adres.com',
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'E-posta adresi zorunludur.';
                              }
                              final regex = RegExp(
                                r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                              );
                              if (!regex.hasMatch(value.trim())) {
                                return 'Geçerli bir e-posta adresi girin.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password
                          AppTextField(
                            controller: _passwordController,
                            label: 'Şifre *',
                            hint: '••••••••',
                            prefixIcon: Icons.lock,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifre zorunludur.';
                              }
                              if (value.length < 8) {
                                return 'Şifre en az 8 karakter olmalıdır.';
                              }
                              if (!value.contains(RegExp(r'[a-zA-Z]')) ||
                                  !value.contains(RegExp(r'[0-9]'))) {
                                return 'Şifre en az bir harf ve bir rakam içermelidir.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password Confirm
                          AppTextField(
                            controller: _passwordConfirmController,
                            label: 'Şifre Tekrar *',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifre tekrarı zorunludur.';
                              }
                              if (value != _passwordController.text) {
                                return 'Şifreler eşleşmiyor.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Submit Button
                          AppButton(
                            label: isLoading ? 'Kayıt Yapılıyor...' : 'Kaydol',
                            isLoading: isLoading,
                            onPressed: isLoading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
