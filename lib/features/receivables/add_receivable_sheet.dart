import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/receivable.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

/// Bottom sheet opened from the floating + button on Alacaklar to add a
/// manual receivable (`type: manuel`).
Future<void> showAddReceivableSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AddReceivableSheet(),
  );
}

class _AddReceivableSheet extends ConsumerStatefulWidget {
  const _AddReceivableSheet();

  @override
  ConsumerState<_AddReceivableSheet> createState() =>
      _AddReceivableSheetState();
}

class _AddReceivableSheetState extends ConsumerState<_AddReceivableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customerController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customerController.dispose();
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
      final receivable = Receivable(
        id: '',
        title: _titleController.text.trim(),
        totalAmount: amount,
        type: '',
        createdBy: uid,
        customerName: _customerController.text.trim().isEmpty
            ? null
            : _customerController.text.trim(),
      );
      await ref.read(firestoreServiceProvider).addManualReceivable(receivable);
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
              'Manuel Alacak Ekle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _customerController,
              decoration: const InputDecoration(
                labelText: 'Müşteri (opsiyonel)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Toplam Tutar (₺)',
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
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
