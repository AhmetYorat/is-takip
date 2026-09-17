import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/app_user.dart';
import '../../core/models/expense.dart';
import '../../core/models/staff_payment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';
import 'add_staff_payment_sheet.dart';
import 'widgets/expense_list_body.dart';
import 'widgets/expense_summary.dart';
import 'widgets/month_bar.dart';

/// Selected month for the Giderler tab and the per-staff detail page it
/// opens into — a plain `StateProvider` (same pattern as [themeModeProvider])
/// so the month picked on one screen stays in sync with the other.
final selectedExpenseMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Giderler screen. Patron sees the company-wide total/category breakdown
/// plus a per-staff-member list (tap through to a person's own detail
/// page); personel only ever sees their own expenses — enforced both by
/// the query scoping here and server-side in `firestore.rules`.
class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPatron =
        ref.watch(currentAppUserProvider).valueOrNull?.isPatron ?? false;
    final month = ref.watch(selectedExpenseMonthProvider);

    return Column(
      children: [
        MonthBar(
          month: month,
          onChanged: (m) =>
              ref.read(selectedExpenseMonthProvider.notifier).state = m,
        ),
        Expanded(
          child: isPatron ? const _PatronExpenses() : const _PersonelExpenses(),
        ),
      ],
    );
  }
}

class _PersonelExpenses extends ConsumerWidget {
  const _PersonelExpenses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    final month = ref.watch(selectedExpenseMonthProvider);
    if (uid == null) return const SizedBox.shrink();

    final expensesAsync = ref.watch(
      myExpensesInMonthProvider((uid: uid, month: month)),
    );
    final staffPayments =
        ref
            .watch(myStaffPaymentsInMonthProvider((uid: uid, month: month)))
            .valueOrNull ??
        const <StaffPayment>[];
    final balance = _balance(
      expenses:
          ref.watch(allTimeExpensesCreatedByProvider(uid)).valueOrNull ??
          const [],
      payments:
          ref.watch(staffPaymentsForStaffProvider(uid)).valueOrNull ?? const [],
    );

    return AsyncValueWidget<List<Expense>>(
      value: expensesAsync,
      data: (expenses) => ExpenseListBody(
        expenses: expenses,
        staffPayments: staffPayments,
        currentUid: uid,
        isPatron: false,
        balance: balance,
        onAddBalancePayment: () =>
            showAddStaffPaymentSheet(context, staffId: uid),
      ),
    );
  }
}

class _PatronExpenses extends ConsumerWidget {
  const _PatronExpenses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedExpenseMonthProvider);
    final expensesAsync = ref.watch(expensesInMonthProvider(month));
    final currentUid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    final staffNames = <String, String>{
      for (final s in ref.watch(staffProvider).valueOrNull ?? const <AppUser>[])
        s.uid: s.name,
    };

    final allTimeExpenses =
        ref.watch(allExpensesAllTimeProvider).valueOrNull ?? const <Expense>[];
    final allTimePayments =
        ref.watch(allStaffPaymentsAllTimeProvider).valueOrNull ??
        const <StaffPayment>[];
    final balancesByPerson = _balancesByPerson(
      expenses: allTimeExpenses,
      payments: allTimePayments,
    );
    final companyBalance = balancesByPerson.values.fold<double>(
      0,
      (sum, b) => sum + b,
    );

    return AsyncValueWidget<List<Expense>>(
      value: expensesAsync,
      data: (expenses) {
        if (expenses.isEmpty && companyBalance == 0) {
          return const EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Bu ay gider kaydı yok',
            message: '+ butonuyla gider ekleyebilirsiniz',
          );
        }

        final totalsByPerson = <String, double>{};
        for (final expense in expenses) {
          totalsByPerson[expense.createdBy] =
              (totalsByPerson[expense.createdBy] ?? 0) + expense.amount;
        }
        // Include anyone with an outstanding all-time balance even if they
        // didn't spend anything this particular month, so patron doesn't
        // lose track of an old debt once the month rolls over.
        final people =
            {...totalsByPerson.keys, ...balancesByPerson.keys}.toList()..sort(
              (a, b) =>
                  (totalsByPerson[b] ?? 0).compareTo(totalsByPerson[a] ?? 0),
            );

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            ExpenseSummary(
              expenses: expenses,
              balance: companyBalance,
              onAddBalancePayment: () => showAddStaffPaymentSheet(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Kişi Bazında',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  for (final id in people) ...[
                    _PersonRow(
                      name: staffNames[id] ?? 'Silinmiş kullanıcı',
                      isSelf: id == currentUid,
                      amount: totalsByPerson[id] ?? 0,
                      balance: balancesByPerson[id] ?? 0,
                      onTap: () =>
                          context.push(AppRoutes.staffExpensesPath(id)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `Σ payments − Σ expenses` for one person, all-time.
double _balance({
  required List<Expense> expenses,
  required List<StaffPayment> payments,
}) {
  final spent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
  return paid - spent;
}

/// Same as [_balance], grouped by person (`Expense.createdBy` /
/// `StaffPayment.staffId`) — used for the patron's company-wide breakdown.
Map<String, double> _balancesByPerson({
  required List<Expense> expenses,
  required List<StaffPayment> payments,
}) {
  final spentByPerson = <String, double>{};
  for (final e in expenses) {
    spentByPerson[e.createdBy] = (spentByPerson[e.createdBy] ?? 0) + e.amount;
  }
  final paidByPerson = <String, double>{};
  for (final p in payments) {
    paidByPerson[p.staffId] = (paidByPerson[p.staffId] ?? 0) + p.amount;
  }
  final everyone = {...spentByPerson.keys, ...paidByPerson.keys};
  return {
    for (final id in everyone)
      id: (paidByPerson[id] ?? 0) - (spentByPerson[id] ?? 0),
  };
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.isSelf,
    required this.amount,
    required this.balance,
    required this.onTap,
  });

  final String name;
  final bool isSelf;
  final double amount;
  final double balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(siz)',
                        style: textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                    ],
                  ],
                ),
                if (balance != 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Bakiye: ${formatCurrency(balance)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: balance < 0 ? colors.danger : colors.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            formatCurrency(amount),
            style: textTheme.titleMedium?.copyWith(color: scheme.error),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: muted),
        ],
      ),
    );
  }
}
