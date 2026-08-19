import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/app_user.dart';

/// Chip-based multi-select for assigning one or more personel to a job.
/// Used both at job creation (patron, optional) and on the job detail page
/// (patron, any time — assignment can always be changed later).
class PersonnelMultiSelect extends StatelessWidget {
  const PersonnelMultiSelect({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<AppUser> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'Kayıtlı personel yok',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((staff) {
        final selected = selectedIds.contains(staff.uid);
        return FilterChip(
          label: Text(
            staff.name,
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
          onSelected: (value) {
            final next = Set<String>.from(selectedIds);
            if (value) {
              next.add(staff.uid);
            } else {
              next.remove(staff.uid);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
