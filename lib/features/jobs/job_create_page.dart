import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/job.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import 'widgets/personnel_multi_select.dart';

/// Job creation form. Personel-created jobs start as `pending_approval`
/// (a patron must assign & approve). Patron-created jobs skip that step
/// entirely and start as `approved`, self-approved, since a patron doesn't
/// need their own sign-off. Either way, the `onJobCreated` Cloud Function
/// automatically creates a matching "(OTOMATİK)" alacak (receivable) entry
/// from [price].
class JobCreatePage extends ConsumerStatefulWidget {
  const JobCreatePage({super.key});

  @override
  ConsumerState<JobCreatePage> createState() => _JobCreatePageState();
}

class _JobCreatePageState extends ConsumerState<JobCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customerController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _scheduledDate = DateTime.now();
  Set<String> _assignedStaffIds = {};
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customerController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return;
    final isPatron =
        ref.read(currentAppUserProvider).valueOrNull?.isPatron ?? false;

    setState(() => _submitting = true);
    try {
      final priceText = _priceController.text.trim();
      final price = priceText.isEmpty
          ? null
          : double.tryParse(priceText.replaceAll(',', '.'));
      final job = Job(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        customerName: _customerController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        scheduledDate: _scheduledDate,
        // Patron doesn't need to approve their own job, and may assign
        // personnel right away.
        status: isPatron ? JobStatus.approved : JobStatus.pendingApproval,
        approvedBy: isPatron ? uid : null,
        assignedTo: isPatron ? _assignedStaffIds.toList() : const [],
        createdBy: uid,
      );
      await ref.read(firestoreServiceProvider).createJob(job);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPatron ? 'İş oluşturuldu.' : 'İş oluşturuldu, onay bekliyor.',
            ),
          ),
        );
      }
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
    final colors = Theme.of(context).extension<AppColors>()!;
    final isPatron =
        ref.watch(currentAppUserProvider).valueOrNull?.isPatron ?? false;
    final personelOptions =
        ref.watch(staffProvider).valueOrNull ?? const <AppUser>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İş Oluştur')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'İş Başlığı',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Müşteri Adı',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Müşteri adı gerekli'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres (opsiyonel)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: _pickScheduledDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Planlanan Tarih',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(formatDate(_scheduledDate)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Açıklama gerekli' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺) (opsiyonel)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  final value = double.tryParse(text.replaceAll(',', '.'));
                  if (value == null || value <= 0) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
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
                        'Fiyat girilirse Alacaklar sayfasına "(OTOMATİK)" '
                        'olarak eklenir. Boş bırakırsanız İş Detayı\'ndan '
                        'sonradan girebilirsiniz.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPatron) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Personel Ata (opsiyonel)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                PersonnelMultiSelect(
                  options: personelOptions,
                  selectedIds: _assignedStaffIds,
                  onChanged: (next) => setState(() => _assignedStaffIds = next),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
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
                    : const Text('İşi Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
