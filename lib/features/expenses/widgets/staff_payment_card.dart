import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/staff_payment.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';

/// A single reimbursement entry ("patron X TL geri ödedi") shown alongside
/// that month's expenses — the "+" counterpart to [ExpenseCard]'s "-".
/// Append-only, so there's no delete action (see `firestore.rules`).
class StaffPaymentCard extends StatelessWidget {
  const StaffPaymentCard({super.key, required this.payment, this.creatorName});

  final StaffPayment payment;

  /// Who recorded this reimbursement, shown to patrons only (personel
  /// already only see their own balance).
  final String? creatorName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_downward_rounded,
              color: colors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.note?.isNotEmpty == true ? payment.note! : 'Ödeme',
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatRelative(payment.createdAt),
                  style: textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                if (creatorName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ekleyen: $creatorName',
                    style: textTheme.bodyMedium?.copyWith(
                      color: muted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+${formatCurrency(payment.amount)}',
            style: textTheme.titleMedium?.copyWith(color: colors.accent),
          ),
        ],
      ),
    );
  }
}
