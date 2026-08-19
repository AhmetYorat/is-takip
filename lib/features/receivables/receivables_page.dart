import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/receivable.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/receivable_card.dart';

enum _StatusFilter { all, unpaid, partial, paid }

/// Alacaklar (receivables) screen: every debt entry — automatic (from job
/// price) and manual — with search, a status filter, and a running total.
class ReceivablesPage extends ConsumerStatefulWidget {
  const ReceivablesPage({super.key});

  @override
  ConsumerState<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends ConsumerState<ReceivablesPage> {
  // Default view: anything still owed (unpaid + partially paid).
  _StatusFilter _filter = _StatusFilter.unpaid;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final receivablesAsync = ref.watch(receivablesProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Müşteri veya açıklama ara',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            children: [
              _FilterChip(
                label: 'Tümü',
                selected: _filter == _StatusFilter.all,
                onTap: () => setState(() => _filter = _StatusFilter.all),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: 'Ödeme Bekliyor',
                selected: _filter == _StatusFilter.unpaid,
                onTap: () => setState(() => _filter = _StatusFilter.unpaid),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: 'Kısmi Ödendi',
                selected: _filter == _StatusFilter.partial,
                onTap: () => setState(() => _filter = _StatusFilter.partial),
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: 'Ödendi',
                selected: _filter == _StatusFilter.paid,
                onTap: () => setState(() => _filter = _StatusFilter.paid),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<Receivable>>(
            value: receivablesAsync,
            data: (receivables) {
              final query = _query.trim().toLowerCase();
              final filtered = receivables.where((r) {
                final matchesQuery =
                    query.isEmpty ||
                    r.title.toLowerCase().contains(query) ||
                    (r.customerName?.toLowerCase().contains(query) ?? false);
                final matchesFilter = switch (_filter) {
                  _StatusFilter.all => true,
                  // "Ödeme Bekliyor" = still owed anything, whether
                  // untouched or partially paid down.
                  _StatusFilter.unpaid => !r.isFullyPaid,
                  _StatusFilter.partial => r.isPartiallyPaid,
                  _StatusFilter.paid => r.isFullyPaid,
                };
                return matchesQuery && matchesFilter;
              }).toList();

              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.request_page_outlined,
                  title: 'Alacak kaydı yok',
                  message: '+ butonuyla manuel alacak ekleyebilirsiniz',
                );
              }

              final totalRemaining = receivables.fold<double>(
                0,
                (sum, r) => sum + r.remainingAmount,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam Kalan Alacak',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onAccent.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(totalRemaining),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: colors.onAccent),
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
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final receivable = filtered[index];
                        return ReceivableCard(
                          receivable: receivable,
                          onTap: () => context.push(
                            AppRoutes.receivableDetailPath(receivable.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primary,
      side: BorderSide(color: scheme.outlineVariant),
      onSelected: (_) => onTap(),
    );
  }
}
