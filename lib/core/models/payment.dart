import 'package:cloud_firestore/cloud_firestore.dart';

/// A `payments/{id}` document — a tahsilat (money actually received).
///
/// If [receivableId] is set, this payment reduces that receivable's debt
/// (`FirestoreService.addPayment` keeps `Receivable.paidAmount` in sync)
/// and shows up in that receivable's "Ödeme Geçmişi". If [receivableId] is
/// null, it's a standalone entry logged directly from the Tahsilatlar page
/// (not tied to any open alacak) — [customerName]/[description] carry its
/// own context in that case.
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.method,
    required this.createdBy,
    this.receivableId,
    this.customerName,
    this.description,
    this.note,
    this.createdAt,
  });

  final String id;
  final String? receivableId;
  final String? customerName;
  final String? description;
  final double amount;
  final String method;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  bool get isLinkedToReceivable => receivableId != null;

  factory Payment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Payment(
      id: doc.id,
      receivableId: data['receivableId'] as String?,
      customerName: data['customerName'] as String?,
      description: data['description'] as String?,
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      method: (data['method'] as String?) ?? 'diger',
      note: data['note'] as String?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'receivableId': receivableId,
    'customerName': customerName,
    'description': description,
    'amount': amount,
    'method': method,
    'note': note,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
