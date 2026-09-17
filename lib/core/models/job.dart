import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/constants.dart';

/// A `jobs/{id}` document.
///
/// [price] is optional — a job can be created without one. Whenever it's
/// known (at creation, or set later from the job detail page), the
/// `onJobCreated` / `onJobPriceSet` Cloud Functions write a matching
/// "(OTOMATİK)" `receivables` entry for that price. A patron assigns one or
/// more personnel via [assignedTo] (a job can have multiple assignees) and
/// approves it, which flips [status] and triggers the `onJobStatusChanged`
/// Cloud Function to push-notify each new assignee.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.customerName,
    required this.status,
    required this.createdBy,
    this.price,
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

  /// Null or unset means the price hasn't been entered yet. Use [hasPrice]
  /// rather than a raw null-check — it also treats a stray `0` (from legacy
  /// docs) as "no price".
  final double? price;
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

  bool get hasPrice => price != null && price! > 0;

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
      price: (data['price'] as num?)?.toDouble(),
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

  /// Whether [uid] may edit this job's details (title/description/
  /// customer/address/scheduledDate — see [toUpdateMap]) right now. A
  /// patron always can; the creator only while it's still awaiting
  /// approval (once a patron approves it, only the patron edits it
  /// further). Never once finished — editing a completed/rejected job's
  /// history would be misleading even though `firestore.rules` would
  /// technically allow a patron to.
  bool canBeEditedBy({required String uid, required bool isPatron}) {
    if (isCompleted || isRejected) return false;
    return isPatron || (createdBy == uid && isPendingApproval);
  }

  /// Whether [uid] may delete this job — the actual authority lives
  /// server-side in the `deleteJob` Cloud Function (it also checks the
  /// linked automatic receivable hasn't been paid against, which can't be
  /// expressed here). This only gates the UI's delete affordance. Unlike
  /// [canBeEditedBy], not blocked by [isCompleted]/[isRejected] — deleting
  /// a finished-but-unpaid job is fine, the payment check is what protects
  /// real money history.
  bool canBeDeletedBy({required String uid, required bool isPatron}) {
    return isPatron || (createdBy == uid && isPendingApproval);
  }

  /// Serializes an edit to this job's own details. Deliberately omits
  /// [price] (has its own one-time "Fiyat Ekle" flow — see
  /// `job_detail_page.dart`; editing it here would desync the linked
  /// automatic receivable's `totalAmount`, since `onJobPriceSet` only
  /// fires on a null-to-set transition) and [status]/[assignedTo]/
  /// [approvedBy]/[approvedAt]/[createdBy]/[createdAt], which all have
  /// their own dedicated write paths.
  Map<String, dynamic> toUpdateMap() => {
    'title': title,
    'description': description,
    'customerName': customerName,
    'address': address,
    'scheduledDate': scheduledDate != null
        ? Timestamp.fromDate(scheduledDate!)
        : null,
    'updatedAt': FieldValue.serverTimestamp(),
  };

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
