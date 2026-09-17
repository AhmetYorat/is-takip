import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';

/// `‹ Eylül 2026 ›` month picker for the Giderler tab and its per-staff
/// detail page. The forward arrow disables once [month] is the current
/// month — expenses aren't planned ahead, there's nothing to page into.
class MonthBar extends StatelessWidget {
  const MonthBar({super.key, required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(
            formatMonth(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth
                ? null
                : () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}
