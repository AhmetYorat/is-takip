import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/constants.dart';

/// An `expenses/{id}` document — money spent (yakıt, yemek, malzeme...),
/// unrelated to any job/customer. Unlike [ExpenseCategory]'s sibling
/// `payments` collection, expenses aren't append-only: the creator or a
/// patron may delete a wrongly entered one (see `firestore.rules`).
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String description;
  final String category;
  final String createdBy;
  final DateTime? createdAt;

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Expense(
      id: doc.id,
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? ExpenseCategory.diger,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'amount': amount,
    'description': description,
    'category': category,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
