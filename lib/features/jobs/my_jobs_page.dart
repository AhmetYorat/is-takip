import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../core/models/job.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/async_value_widget.dart';
import 'widgets/job_date_filter_bar.dart';
import 'widgets/job_list_view.dart';
import 'widgets/pending_count_tab_label.dart';

/// Personel's "İşler" screen, mirroring the patron's structure with three
/// tabs:
/// - **Onay Bekleyen**: jobs this personel created that the patron hasn't
///   approved yet (Firestore query `createdBy == uid`).
/// - **Aktif**: jobs assigned to them that aren't completed yet (Firestore
///   query `assignedTo array-contains uid`, filtered client-side), with the
///   same Bugün/Yarın/Tümü date filter + date sort as the patron's "Aktif".
/// - **Tamamlandı**: their assigned jobs that are completed.
/// Neither list is a client-side filter of every job in the system — see
/// FirestoreService.watchJobsCreatedBy / watchMyJobs.
class MyJobsPage extends ConsumerStatefulWidget {
  const MyJobsPage({super.key});

  @override
  ConsumerState<MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends ConsumerState<MyJobsPage> {
  JobDateFilter _dateFilter = JobDateFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return const SizedBox.shrink();

    final createdJobsAsync = ref.watch(myCreatedJobsProvider(uid));
    final assignedJobsAsync = ref.watch(myJobsProvider(uid));
    final staffNames = <String, String>{
      for (final staff in ref.watch(staffProvider).valueOrNull ?? [])
        staff.uid: staff.name,
    };

    final pendingCount =
        createdJobsAsync.valueOrNull
            ?.where((j) => j.status == JobStatus.pendingApproval)
            .length ??
        0;

    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Aktif
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İşler'),
          bottom: TabBar(
            tabs: [
              Tab(child: PendingCountTabLabel(count: pendingCount)),
              const Tab(text: 'Aktif'),
              const Tab(text: 'Tamamlandı'),
            ],
          ),
        ),
        body: AsyncValueWidget<List<Job>>(
          value: assignedJobsAsync,
          data: (assignedJobs) {
            // Not completed = Aktif; completed = Tamamlandı.
            final active = assignedJobs
                .where((j) => j.status != JobStatus.completed)
                .toList();
            final done = assignedJobs
                .where((j) => j.status == JobStatus.completed)
                .toList();
            final filteredActive = applyJobDateFilter(active, _dateFilter);

            return TabBarView(
              children: [
                AsyncValueWidget<List<Job>>(
                  value: createdJobsAsync,
                  data: (jobs) => JobListView(
                    jobs: jobs
                        .where((j) => j.status == JobStatus.pendingApproval)
                        .toList(),
                    staffNames: staffNames,
                    emptyMessage: 'Onay bekleyen iş yok',
                  ),
                ),
                Column(
                  children: [
                    JobDateFilterBar(
                      value: _dateFilter,
                      onChanged: (filter) =>
                          setState(() => _dateFilter = filter),
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
