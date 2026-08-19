import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/edit_name_dialog.dart';
import '../../core/widgets/empty_state.dart';

/// Patron-only "Personeller" screen. Lets a patron flip any user's role
/// between personel and patron (`users/{uid}.role`, enforced patron-only
/// by firestore.rules).
class StaffListPage extends ConsumerWidget {
  const StaffListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);
    final currentUid = ref.watch(authStateChangesProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Personeller')),
      body: AsyncValueWidget<List<AppUser>>(
        value: staffAsync,
        data: (staff) {
          if (staff.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Henüz kayıtlı kullanıcı yok',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: staff.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final user = staff[index];
              return _StaffCard(
                user: user,
                isSelf: user.uid == currentUid,
                onRoleChanged: (role) =>
                    _confirmRoleChange(context, ref, user, role),
                onEditName: () => _showEditNameDialog(context, ref, user),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRoleChange(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    String newRole,
  ) async {
    final roleLabel = newRole == AppRole.patron ? 'Patron' : 'Personel';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rolü değiştir'),
        content: Text(
          '${user.name} kullanıcısının rolünü $roleLabel olarak değiştirmek '
          'istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Değiştir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(firestoreServiceProvider).updateUserRole(user.uid, newRole);
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final newName = await EditNameDialog.show(context, initialName: user.name);
    if (newName == null || newName == user.name) return;
    await ref.read(firestoreServiceProvider).updateUserName(user.uid, newName);
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.user,
    required this.isSelf,
    required this.onRoleChanged,
    required this.onEditName,
  });

  final AppUser user;
  final bool isSelf;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: textTheme.titleMedium?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(siz)',
                            style: textTheme.bodyMedium?.copyWith(color: muted),
                          ),
                        ],
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onEditName,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      user.email,
                      style: textTheme.bodyMedium?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: AppRole.personel, label: Text('Personel')),
                ButtonSegment(value: AppRole.patron, label: Text('Patron')),
              ],
              selected: {user.role},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onRoleChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
