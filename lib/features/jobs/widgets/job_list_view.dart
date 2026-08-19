import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/models/job.dart';
import '../../../core/widgets/empty_state.dart';
import 'job_card.dart';

/// Scrollable list of [JobCard]s (or an empty state) — one tab's worth of
/// jobs, shared by both "İşler" (patron) and "İşlerim" (personel).
class JobListView extends StatelessWidget {
  const JobListView({
    super.key,
    required this.jobs,
    required this.staffNames,
    required this.emptyMessage,
  });

  final List<Job> jobs;
  final Map<String, String> staffNames;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return EmptyState(icon: Icons.work_outline, title: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobCard(
          job: job,
          assignedToNames: job.assignedTo
              .map((uid) => staffNames[uid])
              .whereType<String>()
              .toList(),
          onTap: () => context.push(AppRoutes.jobDetailPath(job.id)),
        );
      },
    );
  }
}
