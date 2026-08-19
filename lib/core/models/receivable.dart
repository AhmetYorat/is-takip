import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/constants.dart';

/// A `receivables/{id}` document — money owed by a customer.
///
/// [type] is either [ReceivableType.otomatik] (written by the
/// `onJobCreated` Cloud Function from a job's price, shown with an
/// "(OTOMATİK)" badge and linked via [jobId]) or [ReceivableType.manuel]
/// (added by a user through the + button on the Alacaklar page).
///
/// [paidAmount] is denormalized on this doc (kept in sync by
/// `FirestoreService.addPayment` whenever a [Payment] links to this
/// receivable) so list views can show progress/status without opening each
/// receivable's payment history.
class Receivable {
  const Receivable({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.type,
    required this.createdBy,
    this.paidAmount = 0,
    this.jobId,
    this.customerName,
    this.createdAt,
  });

  final String id;
  final String title;
  final double totalAmount;
  final double paidAmount;
  final String type;
  final String createdBy;
  final String? jobId;
  final String? customerName;
  final DateTime? createdAt;

  bool get isAutomatic => type == ReceivableType.otomatik;

  /// Display title: automatic entries always show the "(OTOMATİK)" suffix
  /// regardless of what's stored, so renames upstream can't drop the badge.
  String get displayTitle => isAutomatic ? '$title (OTOMATİK)' : title;

  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, totalAmount);

  bool get isUnpaid => paidAmount <= 0;
  bool get isPartiallyPaid => paidAmount > 0 && paidAmount < totalAmount;
  bool get isFullyPaid => paidAmount >= totalAmount && totalAmount > 0;

  factory Receivable.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Receivable(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      totalAmount: ((data['totalAmount'] as num?) ?? 0).toDouble(),
      paidAmount: ((data['paidAmount'] as num?) ?? 0).toDouble(),
      type: (data['type'] as String?) ?? ReceivableType.manuel,
      createdBy: (data['createdBy'] as String?) ?? '',
      jobId: data['jobId'] as String?,
      customerName: data['customerName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toManualCreateMap() => {
    'title': title,
    'totalAmount': totalAmount,
    'paidAmount': 0,
    'type': ReceivableType.manuel,
    'jobId': null,
    'customerName': customerName,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
