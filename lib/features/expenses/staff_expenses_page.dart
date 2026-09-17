import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/models/expense.dart';
import '../../core/models/staff_payment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/async_value_widget.dart';
import 'add_staff_payment_sheet.dart';
import 'expenses_page.dart' show selectedExpenseMonthProvider;
import 'widgets/expense_list_body.dart';
import 'widgets/month_bar.dart';

/// Patron drilling into one staff member's Giderler — reached by tapping a
/// row on the company-wide [ExpensesPage]. Shares [selectedExpenseMonthProvider]
/// with that page so the month picked on either screen stays in sync.
class StaffExpensesPage extends ConsumerWidget {
  const StaffExpensesPage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedExpenseMonthProvider);
    final expensesAsync = ref.watch(
      myExpensesInMonthProvider((uid: uid, month: month)),
    );
    final currentUid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    final staffNames = <String, String>{
      for (final s in ref.watch(staffProvider).valueOrNull ?? const <AppUser>[])
        s.uid: s.name,
    };
    final staffPayments =
        ref
            .watch(myStaffPaymentsInMonthProvider((uid: uid, month: month)))
            .valueOrNull ??
        const <StaffPayment>[];
    final allTimeExpenseTotal =
        (ref.watch(allTimeExpensesCreatedByProvider(uid)).valueOrNull ??
                const <Expense>[])
            .fold<double>(0, (sum, e) => sum + e.amount);
    final allTimePaymentTotal =
        (ref.watch(staffPaymentsForStaffProvider(uid)).valueOrNull ??
                const <StaffPayment>[])
            .fold<double>(0, (sum, p) => sum + p.amount);
    final balance = allTimePaymentTotal - allTimeExpenseTotal;

    return Scaffold(
      appBar: AppBar(title: Text(staffNames[uid] ?? 'Silinmiş kullanıcı')),
      body: SafeArea(
        child: Column(
          children: [
            MonthBar(
              month: month,
              onChanged: (m) =>
                  ref.read(selectedExpenseMonthProvider.notifier).state = m,
            ),
            Expanded(
              child: AsyncValueWidget<List<Expense>>(
                value: expensesAsync,
                data: (expenses) => ExpenseListBody(
                  expenses: expenses,
                  staffPayments: staffPayments,
                  currentUid: currentUid,
                  // Patron viewing this page — always allowed to delete.
                  isPatron: true,
                  balance: balance,
                  onAddBalancePayment: () =>
                      showAddStaffPaymentSheet(context, staffId: uid),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
