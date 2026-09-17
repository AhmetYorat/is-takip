import 'package:cloud_firestore/cloud_firestore.dart';

/// A `staffPayments/{id}` document — money the company actually paid a
/// staff member back for what they've spent (see `expenses`). [staffId] is
/// who *received* the money and owns the balance it reduces; [createdBy] is
/// who *recorded* it (a patron paying someone, or the staff member logging
/// their own "aldım"). Append-only, like `payments` — a real money movement
/// is never edited or deleted once recorded (see `firestore.rules`).
class StaffPayment {
  const StaffPayment({
    required this.id,
    required this.staffId,
    required this.amount,
    required this.createdBy,
    this.note,
    this.createdAt,
  });

  final String id;
  final String staffId;
  final double amount;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  factory StaffPayment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return StaffPayment(
      id: doc.id,
      staffId: (data['staffId'] as String?) ?? '',
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      note: data['note'] as String?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'staffId': staffId,
    'amount': amount,
    'note': note,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
