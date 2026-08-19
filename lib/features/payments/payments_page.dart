import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/payment.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/payment_card.dart';

/// Tahsilatlar screen: payments received — whether they paid down a
/// specific alacak (`receivableId` set) or were logged standalone.
///
/// Patron sees every payment, with who recorded it. Personel only sees
/// payments they personally added (a colleague's tahsilatlar aren't
/// visible to them) — enforced both here (query scoping) and server-side
/// in `firestore.rules`.
class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    final isPatron = appUser?.isPatron ?? false;

    final paymentsAsync = isPatron || uid == null
        ? ref.watch(paymentsProvider)
        : ref.watch(paymentsCreatedByProvider(uid));

    final receivableTitles = <String, String>{
      for (final r in ref.watch(receivablesProvider).valueOrNull ?? [])
        r.id: r.displayTitle,
    };
    final staffNames = <String, String>{
      for (final s in ref.watch(staffProvider).valueOrNull ?? []) s.uid: s.name,
    };
    final colors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return AsyncValueWidget<List<Payment>>(
      value: paymentsAsync,
      data: (payments) {
        if (payments.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Henüz tahsilat kaydı yok',
            message: '+ butonuyla tahsilat ekleyebilirsiniz',
          );
        }

        final total = payments.fold<double>(0, (sum, p) => sum + p.amount);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toplam Tahsilat',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onAccent.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(total),
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.onAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                itemCount: payments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return PaymentCard(
                    payment: payment,
                    title: payment.receivableId != null
                        ? receivableTitles[payment.receivableId]
                        : null,
                    creatorName: isPatron
                        ? staffNames[payment.createdBy]
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
