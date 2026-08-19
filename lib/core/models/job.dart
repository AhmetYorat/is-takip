import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/constants.dart';

/// A `jobs/{id}` document.
///
/// Personel creates a job with a [price]; the `onJobCreated` Cloud Function
/// then writes a matching "(OTOMATİK)" `collections` entry for that price.
/// A patron assigns one or more personnel via [assignedTo] (a job can have
/// multiple assignees) and approves it, which flips [status] and triggers
/// the `onJobStatusChanged` Cloud Function to push-notify each new assignee.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.customerName,
    required this.status,
    required this.createdBy,
    this.address,
    this.scheduledDate,
    this.assignedTo = const [],
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String customerName;
  final String? address;

  /// The planned work date, set at creation (defaults to today). Drives the
  /// "Bugün"/"Yarın" filters and the date sort on the Aktif tab.
  final DateTime? scheduledDate;
  final String status;
  final String createdBy;

  /// Uids of every personel assigned to this job. Empty means unassigned.
  final List<String> assignedTo;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isUnassigned => assignedTo.isEmpty;
  bool isAssignedTo(String uid) => assignedTo.contains(uid);

  bool get isPendingApproval => status == JobStatus.pendingApproval;
  bool get isApproved => status == JobStatus.approved;
  bool get isInProgress => status == JobStatus.inProgress;
  bool get isCompleted => status == JobStatus.completed;
  bool get isRejected => status == JobStatus.rejected;

  bool get isScheduledToday {
    final date = scheduledDate;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isScheduledTomorrow {
    final date = scheduledDate;
    if (date == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  factory Job.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Job(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      customerName: (data['customerName'] as String?) ?? '',
      address: data['address'] as String?,
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate(),
      status: (data['status'] as String?) ?? JobStatus.pendingApproval,
      createdBy: (data['createdBy'] as String?) ?? '',
      // Tolerate legacy docs written before assignedTo became a list (it
      // used to be a single uid string).
      assignedTo: switch (data['assignedTo']) {
        final List<dynamic> list => list.cast<String>(),
        final String uid when uid.isNotEmpty => [uid],
        _ => const <String>[],
      },
      approvedBy: data['approvedBy'] as String?,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Serializes this job for creation. [status], [approvedBy] and
  /// [assignedTo] are read directly off the instance so the caller controls
  /// whether it starts as `pending_approval` (personel-created) or already
  /// `approved` (patron-created — patron doesn't need to approve their own
  /// job, and may optionally assign a personel right away).
  Map<String, dynamic> toCreateMap() => {
    'title': title,
    'description': description,
    'price': price,
    'customerName': customerName,
    'address': address,
    'scheduledDate': scheduledDate != null
        ? Timestamp.fromDate(scheduledDate!)
        : null,
    'status': status,
    'createdBy': createdBy,
    'assignedTo': assignedTo,
    'approvedBy': approvedBy,
    'approvedAt': approvedBy != null ? FieldValue.serverTimestamp() : null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
