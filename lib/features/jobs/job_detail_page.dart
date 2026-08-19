import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/job.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import 'widgets/personnel_multi_select.dart';

class JobDetailPage extends ConsumerWidget {
  const JobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobByIdProvider(jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('İş Detayı')),
      body: AsyncValueWidget<Job?>(
        value: jobAsync,
        data: (job) {
          if (job == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'İş bulunamadı',
            );
          }
          return _JobDetailBody(job: job);
        },
      ),
    );
  }
}

class _JobDetailBody extends ConsumerStatefulWidget {
  const _JobDetailBody({required this.job});

  final Job job;

  @override
  ConsumerState<_JobDetailBody> createState() => _JobDetailBodyState();
}

class _JobDetailBodyState extends ConsumerState<_JobDetailBody> {
  late Set<String> _selectedStaffIds = widget.job.assignedTo.toSet();
  bool _submitting = false;

  Future<void> _assignAndApprove(String patronUid) async {
    if (_selectedStaffIds.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .assignAndApproveJob(
            jobId: widget.job.id,
            assignedTo: _selectedStaffIds.toList(),
            approvedBy: patronUid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İş atandı ve onaylandı.')),
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

  Future<void> _updateAssignedPersonnel() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateAssignedPersonnel(
            jobId: widget.job.id,
            assignedTo: _selectedStaffIds.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Personel güncellendi.')));
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

  Future<void> _reject() async {
    setState(() => _submitting = true);
    try {
      await ref.read(firestoreServiceProvider).rejectJob(widget.job.id);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateJobStatus(widget.job.id, status);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Patron-only quick status override, opened by tapping the status chip.
  /// Only forward/terminal transitions are offered here — approval itself
  /// happens through the "Personel Ata" flow above, not this picker.
  Future<void> _showStatusPicker() async {
    const statusLabels = {
      JobStatus.inProgress: 'Devam Ediyor',
      JobStatus.completed: 'Tamamlandı',
      JobStatus.rejected: 'İptal',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Durumu değiştir',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final entry in statusLabels.entries)
              Builder(
                builder: (context) {
                  final (_, color) = jobStatusVisuals(context, entry.key);
                  return ListTile(
                    leading: Icon(Icons.circle, size: 12, color: color),
                    title: Text(entry.value),
                    trailing: entry.key == widget.job.status
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != widget.job.status) {
      await _updateStatus(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final staff = ref.watch(staffProvider).valueOrNull ?? const <AppUser>[];
    final staffNames = <String, String>{for (final s in staff) s.uid: s.name};
    final assignedNames = job.assignedTo
        .map((uid) => staffNames[uid])
        .whereType<String>()
        .toList();
    final personelOptions = staff;
    final selectionUnchanged = setEquals(
      _selectedStaffIds,
      job.assignedTo.toSet(),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(child: Text(job.title, style: textTheme.headlineSmall)),
              StatusChip(
                status: job.status,
                onTap: (appUser?.isPatron ?? false) ? _showStatusPicker : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatCurrency(job.price),
            style: textTheme.headlineSmall?.copyWith(color: colors.accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Müşteri',
            value: job.customerName,
          ),
          if (job.address != null)
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Adres',
              value: job.address!,
            ),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Atanan Personel',
            value: assignedNames.isEmpty
                ? 'Atanmadı'
                : assignedNames.join(', '),
          ),
          _InfoRow(
            icon: Icons.person_add_alt_outlined,
            label: 'Oluşturan',
            value: staffNames[job.createdBy] ?? 'Bilinmiyor',
          ),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'Oluşturulma',
            value: formatDateTime(job.createdAt),
          ),
          if (job.approvedBy != null)
            _InfoRow(
              icon: Icons.verified_outlined,
              label: 'Onaylayan',
              value: staffNames[job.approvedBy!] ?? 'Bilinmiyor',
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Açıklama', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            job.description,
            style: textTheme.bodyLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Patron: assign personnel — either approving a pending job, or
          // adjusting who's staffed on an already-approved job (assignment
          // can always be changed later, not just once).
          if (appUser != null &&
              appUser.isPatron &&
              !job.isCompleted &&
              !job.isRejected) ...[
            Text('Personel Ata', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            PersonnelMultiSelect(
              options: personelOptions,
              selectedIds: _selectedStaffIds,
              onChanged: (next) => setState(() => _selectedStaffIds = next),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed:
                  (_submitting ||
                      (job.isPendingApproval
                          ? _selectedStaffIds.isEmpty
                          : selectionUnchanged))
                  ? null
                  : () => job.isPendingApproval
                        ? _assignAndApprove(appUser.uid)
                        : _updateAssignedPersonnel(),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      job.isPendingApproval
                          ? 'Ata & Onayla'
                          : 'Personelleri Güncelle',
                    ),
            ),
            if (job.isPendingApproval) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _submitting ? null : _reject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                child: const Text('Reddet'),
              ),
            ],
          ],

          // Personel: progress their own assigned job.
          if (appUser != null &&
              appUser.isPersonel &&
              job.isAssignedTo(appUser.uid)) ...[
            if (job.isApproved)
              FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _updateStatus(JobStatus.inProgress),
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('İşi Başlat'),
              ),
            if (job.isInProgress)
              FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _updateStatus(JobStatus.completed),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Tamamlandı Olarak İşaretle'),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
