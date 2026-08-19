import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/payment.dart';
import '../../core/models/receivable.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';
import '../payments/add_payment_sheet.dart';
import '../payments/widgets/payment_card.dart';

class ReceivableDetailPage extends ConsumerWidget {
  const ReceivableDetailPage({super.key, required this.receivableId});

  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivableAsync = ref.watch(receivableByIdProvider(receivableId));

    return Scaffold(
      appBar: AppBar(title: const Text('Alacak Detayı')),
      body: AsyncValueWidget<Receivable?>(
        value: receivableAsync,
        data: (receivable) {
          if (receivable == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Alacak bulunamadı',
            );
          }
          return _ReceivableDetailBody(receivable: receivable);
        },
      ),
    );
  }
}

class _ReceivableDetailBody extends ConsumerWidget {
  const _ReceivableDetailBody({required this.receivable});

  final Receivable receivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    final paymentsAsync = ref.watch(
      paymentsForReceivableProvider(receivable.id),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      receivable.displayTitle,
                      style: textTheme.headlineSmall,
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
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Tutar Bilgileri', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.payments_outlined,
                      label: 'Toplam',
                      value: formatCurrency(receivable.totalAmount),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Ödenen',
                      value: formatCurrency(receivable.paidAmount),
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.error_outline,
                      label: 'Kalan',
                      value: formatCurrency(receivable.remainingAmount),
                      color: colors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AsyncValueWidget<List<Payment>>(
                value: paymentsAsync,
                loading: () => const SizedBox.shrink(),
                data: (payments) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Ödeme Geçmişi', style: textTheme.titleMedium),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${payments.length}',
                              style: textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (payments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Center(
                            child: Text(
                              'Henüz ödeme kaydı yok',
                              style: textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        )
                      else
                        ...payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: PaymentCard(payment: payment),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: () =>
                  showAddPaymentSheet(context, receivable: receivable),
              icon: const Icon(Icons.add),
              label: const Text('Ödeme Ekle'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(color: color, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
