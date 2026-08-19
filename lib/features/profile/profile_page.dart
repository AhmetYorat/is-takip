import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/edit_name_dialog.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.accentMuted,
                    child: Text(
                      appUser != null && appUser.name.isNotEmpty
                          ? appUser.name[0].toUpperCase()
                          : '?',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colors.accent,
                      ),
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
                                appUser?.name ?? '-',
                                style: textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (appUser != null) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showEditNameDialog(
                                  context,
                                  ref,
                                  appUser.name,
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appUser?.email ?? '-',
                          style: textTheme.bodyMedium?.copyWith(color: muted),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Text(
                            appUser?.role == AppRole.patron
                                ? 'Patron'
                                : 'Personel',
                            style: textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Görünüm', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (mode) =>
                    ref.read(themeModeProvider.notifier).state = mode!,
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text('Sistem'),
                      value: ThemeMode.system,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Açık'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text('Koyu'),
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () async {
                final uid = appUser?.uid;
                if (uid != null) {
                  await ref.read(messagingServiceProvider).clearToken(uid);
                }
                await ref.read(authServiceProvider).signOut();
              },
              icon: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Çıkış Yap',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditNameDialog(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) async {
  final newName = await EditNameDialog.show(
    context,
    initialName: currentName,
    title: 'Adınızı düzenleyin',
  );
  if (newName == null || newName == currentName) return;
  await ref.read(authServiceProvider).updateOwnName(newName);
}
