import 'package:flutter/material.dart';
import 'package:sirasende_mobile/features/appointment/domain/models/appointment_draft.dart';
import 'package:sirasende_mobile/features/appointment/presentation/models/appointment_form_args.dart';
import 'package:sirasende_mobile/features/business/presentation/helpers/datetime_helpers.dart';

class AppointmentFormScreen extends StatefulWidget {
  final AppointmentFormArgs args;
  final ValueChanged<AppointmentDraft>? onValidSubmit;

  const AppointmentFormScreen({
    super.key,
    required this.args,
    this.onValidSubmit,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
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

  @override
  Widget build(BuildContext context) {
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(widget.args.date);
    } catch (_) {}
    final dateText = parsedDate != null
        ? formatTurkishDate(parsedDate)
        : widget.args.date;

    return Scaffold(
      appBar: AppBar(title: const Text('Randevu Bilgileri')),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection Summary Card
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.args.businessName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateText,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.args.startTime} – ${widget.args.endTime}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Müşteri Bilgileri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
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
                const SizedBox(height: 20),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon Numarası',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '05xx xxx xx xx',
                  ),
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
                const SizedBox(height: 20),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Not (İsteğe Bağlı)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value != null && value.length > 1000) {
                      return 'Not en fazla 1000 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
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
                      }
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
