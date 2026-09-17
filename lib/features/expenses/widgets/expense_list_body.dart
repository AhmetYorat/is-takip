import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/expense.dart';
import '../../../core/models/staff_payment.dart';
import '../../../core/widgets/empty_state.dart';
import 'expense_card.dart';
import 'expense_summary.dart';
import 'staff_payment_card.dart';

/// Summary card + flat expense/reimbursement list for "one person, one
/// month" — used by personel's own Giderler view and the patron's
/// per-staff-member detail page. [currentUid] + [isPatron] decide which
/// expense cards get a delete button (mirrors `firestore.rules`: the
/// expense's own creator, or a patron); [staffPayments] are always
/// append-only (see [StaffPaymentCard]).
///
/// [balance] and [onAddBalancePayment] are forwarded to [ExpenseSummary] —
/// see its doc for why the balance is all-time rather than month-scoped.
class ExpenseListBody extends StatelessWidget {
  const ExpenseListBody({
    super.key,
    required this.expenses,
    required this.staffPayments,
    required this.currentUid,
    required this.isPatron,
    this.balance,
    this.onAddBalancePayment,
  });

  final List<Expense> expenses;
  final List<StaffPayment> staffPayments;
  final String? currentUid;
  final bool isPatron;
  final double? balance;
  final VoidCallback? onAddBalancePayment;

  @override
  Widget build(BuildContext context) {
    final hasBalanceHistory = balance != null && balance != 0;
    if (expenses.isEmpty && staffPayments.isEmpty && !hasBalanceHistory) {
      return const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Bu ay gider kaydı yok',
        message: '+ butonuyla gider ekleyebilirsiniz',
      );
    }

    final entries = <(DateTime?, Widget)>[
      for (final expense in expenses)
        (
          expense.createdAt,
          ExpenseCard(
            expense: expense,
            canDelete: isPatron || expense.createdBy == currentUid,
          ),
        ),
      for (final payment in staffPayments)
        (payment.createdAt, StaffPaymentCard(payment: payment)),
    ]..sort((a, b) => (b.$1 ?? DateTime(0)).compareTo(a.$1 ?? DateTime(0)));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        ExpenseSummary(
          expenses: expenses,
          balance: balance,
          onAddBalancePayment: onAddBalancePayment,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            'Giderler',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text('Bu ay kayıt yok'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                for (final entry in entries) ...[
                  entry.$2,
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
