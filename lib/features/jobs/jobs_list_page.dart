import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../core/models/job.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/async_value_widget.dart';
import 'widgets/job_date_filter_bar.dart';
import 'widgets/job_list_view.dart';
import 'widgets/pending_count_tab_label.dart';

/// Patron's "İşler" screen: every job in the system, split into
/// Onay Bekleyen / Aktif / Tamamlanan tabs. Opens on Aktif by default, with
/// a pending-count badge on Onay Bekleyen and a Bugün/Yarın date filter +
/// date sort on Aktif.
class JobsListPage extends ConsumerStatefulWidget {
  const JobsListPage({super.key});

  @override
  ConsumerState<JobsListPage> createState() => _JobsListPageState();
}

class _JobsListPageState extends ConsumerState<JobsListPage> {
  JobDateFilter _activeFilter = JobDateFilter.all;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(allJobsProvider);
    final staffAsync = ref.watch(staffProvider);
    final staffNames = <String, String>{
      for (final staff in staffAsync.valueOrNull ?? []) staff.uid: staff.name,
    };

    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Aktif
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İşler'),
          bottom: TabBar(
            tabs: [
              Tab(
                child: PendingCountTabLabel(
                  count:
                      jobsAsync.valueOrNull
                          ?.where((j) => j.status == JobStatus.pendingApproval)
                          .length ??
                      0,
                ),
              ),
              const Tab(text: 'Aktif'),
              const Tab(text: 'Tamamlanan'),
            ],
          ),
        ),
        body: AsyncValueWidget<List<Job>>(
          value: jobsAsync,
          data: (jobs) {
            final pending = jobs
                .where((j) => j.status == JobStatus.pendingApproval)
                .toList();
            final active = jobs
                .where(
                  (j) =>
                      j.status == JobStatus.approved ||
                      j.status == JobStatus.inProgress,
                )
                .toList();
            final done = jobs
                .where(
                  (j) =>
                      j.status == JobStatus.completed ||
                      j.status == JobStatus.rejected,
                )
                .toList();

            final filteredActive = applyJobDateFilter(active, _activeFilter);

            return TabBarView(
              children: [
                JobListView(
                  jobs: pending,
                  staffNames: staffNames,
                  emptyMessage: 'Onay bekleyen iş yok',
                ),
                Column(
                  children: [
                    JobDateFilterBar(
                      value: _activeFilter,
                      onChanged: (filter) =>
                          setState(() => _activeFilter = filter),
                    ),
                    Expanded(
                      child: JobListView(
                        jobs: filteredActive,
                        staffNames: staffNames,
                        emptyMessage: 'Aktif iş yok',
                      ),
                    ),
                  ],
                ),
                JobListView(
                  jobs: done,
                  staffNames: staffNames,
                  emptyMessage: 'Tamamlanan iş yok',
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push(AppRoutes.jobCreate),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
