import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/job.dart';

enum JobDateFilter { all, today, tomorrow }

/// Filters [jobs] by [filter] (today/tomorrow/all, based on
/// `Job.scheduledDate`) and sorts the result by that date ascending —
/// shared by the patron's "Aktif" tab and the personel's "İşlerim" tab so
/// both behave identically.
List<Job> applyJobDateFilter(List<Job> jobs, JobDateFilter filter) {
  final filtered = switch (filter) {
    JobDateFilter.all => jobs,
    JobDateFilter.today => jobs.where((j) => j.isScheduledToday).toList(),
    JobDateFilter.tomorrow => jobs.where((j) => j.isScheduledTomorrow).toList(),
  };
  filtered.sort((a, b) {
    final aDate = a.scheduledDate;
    final bDate = b.scheduledDate;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return filtered;
}

/// Tümü/Bugün/Yarın chip row for filtering a job list by `scheduledDate`.
class JobDateFilterBar extends StatelessWidget {
  const JobDateFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final JobDateFilter value;
  final ValueChanged<JobDateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          _Chip(
            label: 'Tümü',
            selected: value == JobDateFilter.all,
            onTap: () => onChanged(JobDateFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Chip(
            label: 'Bugün',
            selected: value == JobDateFilter.today,
            onTap: () => onChanged(JobDateFilter.today),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Chip(
            label: 'Yarın',
            selected: value == JobDateFilter.tomorrow,
            onTap: () => onChanged(JobDateFilter.tomorrow),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primary,
      side: BorderSide(color: scheme.outlineVariant),
      onSelected: (_) => onTap(),
    );
  }
}
