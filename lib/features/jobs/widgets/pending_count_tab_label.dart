import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// "Onay Bekleyen" tab label with a small badge showing how many jobs are
/// pending — shared by patron's "İşler" and personel's "İşlerim".
class PendingCountTabLabel extends StatelessWidget {
  const PendingCountTabLabel({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Text('Onay Bekleyen');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Onay Bekleyen'),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
