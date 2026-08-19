import 'package:flutter/material.dart';

import '../../../app/constants.dart';
import '../../../app/theme.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';

/// A single tahsilat (payment received) entry — used both in the
/// standalone Tahsilatlar list and a receivable's "Ödeme Geçmişi".
class PaymentCard extends StatelessWidget {
  const PaymentCard({
    super.key,
    required this.payment,
    this.title,
    this.creatorName,
  });

  final Payment payment;

  /// Override display title (e.g. the linked receivable's name), falling
  /// back to the payment's own customer/description for standalone entries.
  final String? title;

  /// Who recorded this payment — shown to patrons only (personel already
  /// only see their own).
  final String? creatorName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    final displayTitle =
        title ?? payment.customerName ?? payment.description ?? 'Tahsilat';

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
              _methodIcon(payment.method),
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
                  displayTitle,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${PaymentMethod.label(payment.method)} • ${formatRelative(payment.createdAt)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                if (payment.note != null && payment.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    payment.note!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
            formatCurrency(payment.amount),
            style: textTheme.titleMedium?.copyWith(color: colors.accent),
          ),
        ],
      ),
    );
  }
}

IconData _methodIcon(String method) => switch (method) {
  PaymentMethod.nakit => Icons.payments_outlined,
  PaymentMethod.havale => Icons.account_balance_outlined,
  PaymentMethod.kart => Icons.credit_card_outlined,
  _ => Icons.receipt_long_outlined,
};
