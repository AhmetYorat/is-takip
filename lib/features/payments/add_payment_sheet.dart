import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/payment.dart';
import '../../core/models/receivable.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';

/// Bottom sheet for recording a tahsilat (payment received).
///
/// - From a receivable's detail page, pass [receivable]: the payment links
///   to it (reduces its debt, shows up in its "Ödeme Geçmişi") and this
///   sheet only asks for amount/method/note, showing "Kalan Borç" context.
/// - From the standalone Tahsilatlar page, pass no [receivable]: the
///   payment isn't tied to any alacak, so it also asks for a customer name
///   and description.
/// Either way the payment always appears in the Tahsilatlar list.
Future<void> showAddPaymentSheet(
  BuildContext context, {
  Receivable? receivable,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddPaymentSheet(receivable: receivable),
  );
}

class _AddPaymentSheet extends ConsumerStatefulWidget {
  const _AddPaymentSheet({this.receivable});

  final Receivable? receivable;

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _customerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();
  String _method = PaymentMethod.nakit;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _customerController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
      final payment = Payment(
        id: '',
        receivableId: widget.receivable?.id,
        customerName: widget.receivable == null
            ? (_customerController.text.trim().isEmpty
                  ? null
                  : _customerController.text.trim())
            : null,
        description: widget.receivable == null
            ? (_descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim())
            : null,
        amount: amount,
        method: _method,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdBy: uid,
      );
      await ref.read(firestoreServiceProvider).addPayment(payment);
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
    final receivable = widget.receivable;
    final colors = Theme.of(context).extension<AppColors>()!;

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
            Text(
              'Ödeme / Tahsilat Ekle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (receivable != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.accentMuted,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.accent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Kalan Borç: ${formatCurrency(receivable.remainingAmount)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (receivable == null) ...[
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Müşteri (opsiyonel)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Ödenen Tutar (₺)',
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
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Ödeme Şekli',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: PaymentMethod.all
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(PaymentMethod.label(m)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                prefixIcon: Icon(Icons.edit_note_outlined),
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
