import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/models/expense.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import 'expense_category_icon.dart';

/// A single gider (expense) entry. If [canDelete] (the expense's own
/// creator, or a patron — mirrors `firestore.rules`), a trailing delete
/// icon removes it after a confirmation dialog. There's no edit path — a
/// wrong entry is deleted and re-added.
class ExpenseCard extends ConsumerWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    required this.canDelete,
  });

  final Expense expense;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    final title = expense.description.isEmpty
        ? ExpenseCategory.label(expense.category)
        : expense.description;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              expenseCategoryIcon(expense.category),
              color: scheme.onErrorContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${ExpenseCategory.label(expense.category)} • ${formatRelative(expense.createdAt)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatCurrency(expense.amount),
            style: textTheme.titleMedium?.copyWith(color: scheme.error),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: muted,
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gideri sil'),
        content: const Text(
          'Bu gider kaydını silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider).deleteExpense(expense.id);
  }
}
