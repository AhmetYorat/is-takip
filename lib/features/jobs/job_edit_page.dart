import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/job.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';

/// Edits a job's own details (title/description/customer/address/planned
/// date) — reached from [JobDetailPage]'s "Düzenle" action. Deliberately
/// separate from [JobCreatePage]: that form's price field, "(OTOMATİK)"
/// info card and personnel picker don't apply here, and folding create/edit
/// into one widget risks a mistaken write to `status`/`assignedTo`. See
/// [Job.canBeEditedBy] for who may get here and when.
class JobEditPage extends ConsumerWidget {
  const JobEditPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobByIdProvider(jobId));
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('İşi Düzenle')),
      body: AsyncValueWidget<Job?>(
        value: jobAsync,
        data: (job) {
          if (job == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'İş bulunamadı',
            );
          }
          if (appUser == null ||
              !job.canBeEditedBy(uid: appUser.uid, isPatron: appUser.isPatron)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Bu iş artık düzenlenemez',
            );
          }
          return _JobEditForm(job: job);
        },
      ),
    );
  }
}

class _JobEditForm extends ConsumerStatefulWidget {
  const _JobEditForm({required this.job});

  final Job job;

  @override
  ConsumerState<_JobEditForm> createState() => _JobEditFormState();
}

class _JobEditFormState extends ConsumerState<_JobEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.job.title);
  late final _descriptionController = TextEditingController(
    text: widget.job.description,
  );
  late final _customerController = TextEditingController(
    text: widget.job.customerName,
  );
  late final _addressController = TextEditingController(
    text: widget.job.address ?? '',
  );
  late DateTime _scheduledDate = widget.job.scheduledDate ?? DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customerController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final firstDate = _scheduledDate.isBefore(now)
        ? _scheduledDate
        : now.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final job = widget.job;
      final updated = Job(
        id: job.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        customerName: _customerController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        scheduledDate: _scheduledDate,
        price: job.price,
        status: job.status,
        createdBy: job.createdBy,
        assignedTo: job.assignedTo,
        approvedBy: job.approvedBy,
        approvedAt: job.approvedAt,
        createdAt: job.createdAt,
      );
      await ref
          .read(firestoreServiceProvider)
          .updateJob(jobId: job.id, updated: updated);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İş güncellendi.')));
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
    return SafeArea(
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Müşteri adı gerekli' : null,
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
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
