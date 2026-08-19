import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/receivable.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';

/// Alacak (receivable) summary card: total/paid/remaining amounts, a
/// progress bar, and a status badge computed from payment history — never
/// a manually-set field, so it can't drift out of sync with actual
/// payments.
class ReceivableCard extends StatelessWidget {
  const ReceivableCard({super.key, required this.receivable, this.onTap});

  final Receivable receivable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    final (statusLabel, statusColor) = _statusVisuals(context, receivable);
    final progress = receivable.totalAmount <= 0
        ? 0.0
        : (receivable.paidAmount / receivable.totalAmount).clamp(0.0, 1.0);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  receivable.displayTitle,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  statusLabel,
                  style: textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (receivable.customerName != null &&
              receivable.customerName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              receivable.customerName!,
              style: textTheme.bodyMedium?.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _AmountStat(
                label: 'Toplam',
                value: formatCurrency(receivable.totalAmount),
              ),
              _AmountStat(
                label: 'Ödenen',
                value: formatCurrency(receivable.paidAmount),
                color: colors.accent,
              ),
              _AmountStat(
                label: 'Kalan',
                value: formatCurrency(receivable.remainingAmount),
                color: receivable.remainingAmount > 0
                    ? colors.warning
                    : colors.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatRelative(receivable.createdAt),
            style: textTheme.bodyMedium?.copyWith(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

(String, Color) _statusVisuals(BuildContext context, Receivable receivable) {
  final scheme = Theme.of(context).colorScheme;
  final colors = Theme.of(context).extension<AppColors>()!;
  if (receivable.isFullyPaid) return ('Ödendi', colors.accent);
  if (receivable.isPartiallyPaid) return ('Kısmi Ödendi', scheme.secondary);
  return ('Ödeme Bekliyor', colors.warning);
}

class _AmountStat extends StatelessWidget {
  const _AmountStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
