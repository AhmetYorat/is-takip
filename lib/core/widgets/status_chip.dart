import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';

/// Turkish label + color for a [JobStatus] value, shared by [StatusChip]
/// and the status-change picker on the job detail page.
(String, Color) jobStatusVisuals(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final colors = Theme.of(context).extension<AppColors>()!;
  return switch (status) {
    JobStatus.pendingApproval => ('Onay Bekliyor', colors.warning),
    JobStatus.approved => ('Onaylandı', scheme.primary),
    JobStatus.inProgress => ('Devam Ediyor', scheme.secondary),
    JobStatus.completed => ('Tamamlandı', colors.accent),
    JobStatus.rejected => ('Reddedildi', scheme.error),
    _ => (status, scheme.outline),
  };
}

/// Colored pill badge for a job's [JobStatus]. Color is never the only
/// signal — the Turkish label text always ships alongside it. Pass [onTap]
/// to let the badge itself open a status-change control (e.g. patron
/// editing a job's status from the detail page).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.onTap});

  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = jobStatusVisuals(context, status);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color, fontSize: 12),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 14, color: color),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: chip,
    );
  }
}
