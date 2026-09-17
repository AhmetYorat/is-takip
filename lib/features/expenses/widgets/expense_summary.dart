import 'package:flutter/material.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/models/expense.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import 'expense_category_icon.dart';

/// Total + per-category breakdown for a list of expenses already scoped to
/// one month (and, for personel, one person). Shared by the Giderler tab
/// and the patron's per-staff-member detail page so both render identically.
///
/// [balance] is the separate, all-time reimbursement balance (Σ staff
/// payments − Σ all-time expenses) for whoever [expenses] is scoped to —
/// unlike the month's totals above, it never resets when the month picker
/// changes. Null hides the card (e.g. the patron's company-wide view, which
/// shows balance per person instead — see [ExpensesPage]).
class ExpenseSummary extends StatelessWidget {
  const ExpenseSummary({
    super.key,
    required this.expenses,
    this.balance,
    this.onAddBalancePayment,
  });

  final List<Expense> expenses;
  final double? balance;

  /// Opens the "patron para verdi" sheet. Null hides the `+` button while
  /// still showing the balance itself.
  final VoidCallback? onAddBalancePayment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    final totalsByCategory = <String, double>{};
    for (final expense in expenses) {
      totalsByCategory[expense.category] =
          (totalsByCategory[expense.category] ?? 0) + expense.amount;
    }
    final categories =
        totalsByCategory.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.danger,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toplam Gider',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onDanger.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(total),
                  style: textTheme.headlineMedium?.copyWith(
                    color: colors.onDanger,
                  ),
                ),
              ],
            ),
          ),
          if (balance != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _BalanceCard(balance: balance!, onAdd: onAddBalancePayment),
          ],
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                const columns = 2;
                final cardWidth =
                    (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in categories)
                      _CategoryCard(
                        category: entry.key,
                        amount: entry.value,
                        width: cardWidth,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Running "şirket personele ne kadar borçlu" balance: negative while
/// expenses outweigh reimbursements, back to 0 once they're paid back.
/// Never affects [Expense.amount] — expenses stay exactly what was spent.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, this.onAdd});

  final double balance;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    final amountColor = balance < 0 ? colors.danger : colors.accent;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bakiye',
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(balance),
                  style: textTheme.titleLarge?.copyWith(color: amountColor),
                ),
              ],
            ),
          ),
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle),
              color: colors.accent,
              iconSize: 28,
              tooltip: 'Ödeme ekle',
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.width,
  });

  final String category;
  final double amount;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(expenseCategoryIcon(category), size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ExpenseCategory.label(category),
                    style: textTheme.bodyMedium?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(formatCurrency(amount), style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
