import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/job.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';

/// Job summary card used on both "İşler" (patron) and "İşlerim" (personel).
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.assignedToNames = const [],
  });

  final Job job;
  final VoidCallback onTap;

  /// Resolved display names of `job.assignedTo`, looked up by the parent
  /// page from the staff list (kept out of this widget so it stays
  /// Firestore-agnostic).
  final List<String> assignedToNames;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(status: job.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            job.customerName,
            style: textTheme.bodyMedium?.copyWith(color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (job.scheduledDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: job.isScheduledToday || job.isScheduledTomorrow
                      ? colors.accent
                      : muted,
                ),
                const SizedBox(width: 4),
                Text(
                  _scheduledDateLabel(job),
                  style: textTheme.bodyMedium?.copyWith(
                    color: job.isScheduledToday || job.isScheduledTomorrow
                        ? colors.accent
                        : muted,
                    fontWeight: job.isScheduledToday || job.isScheduledTomorrow
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (job.hasPrice)
                Text(
                  formatCurrency(job.price!),
                  style: textTheme.titleMedium?.copyWith(color: colors.accent),
                ),
              const Spacer(),
              if (assignedToNames.isNotEmpty) ...[
                Icon(Icons.person_outline, size: 16, color: muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    assignedToNames.join(', '),
                    style: textTheme.bodyMedium?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Text(
                  'Atanmadı',
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _scheduledDateLabel(Job job) {
  if (job.isScheduledToday) return 'Bugün';
  if (job.isScheduledTomorrow) return 'Yarın';
  return formatDate(job.scheduledDate);
}
