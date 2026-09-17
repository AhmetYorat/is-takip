import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/staff_payment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

/// Bottom sheet for recording a reimbursement — "patron Ahmet'e 50 TL
/// verdi" gibi. If [staffId] is given (opened from that person's own
/// balance card, or the patron's per-staff-member detail page), the
/// recipient is fixed and no picker is shown; otherwise (patron's
/// company-wide Giderler screen) a dropdown picks who received the money.
/// There's no edit path — see [StaffPayment].
Future<void> showAddStaffPaymentSheet(BuildContext context, {String? staffId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddStaffPaymentSheet(staffId: staffId),
  );
}

class _AddStaffPaymentSheet extends ConsumerStatefulWidget {
  const _AddStaffPaymentSheet({this.staffId});

  final String? staffId;

  @override
  ConsumerState<_AddStaffPaymentSheet> createState() =>
      _AddStaffPaymentSheetState();
}

class _AddStaffPaymentSheetState extends ConsumerState<_AddStaffPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedStaffId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.staffId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    final staffId = _selectedStaffId;
    if (uid == null || staffId == null) return;

    setState(() => _submitting = true);
    try {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
      final note = _noteController.text.trim();
      final payment = StaffPayment(
        id: '',
        staffId: staffId,
        amount: amount,
        note: note.isEmpty ? null : note,
        createdBy: uid,
      );
      await ref.read(firestoreServiceProvider).addStaffPayment(payment);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider).valueOrNull ?? const <AppUser>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ödeme Ekle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            if (widget.staffId == null) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedStaffId,
                decoration: const InputDecoration(
                  labelText: 'Personel',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: staff
                    .map(
                      (u) =>
                          DropdownMenuItem(value: u.uid, child: Text(u.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedStaffId = value),
                validator: (value) =>
                    value == null ? 'Bir personel seçin' : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tutar (₺)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (value == null || value <= 0) {
                  return 'Geçerli bir tutar girin';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Ödeme Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
