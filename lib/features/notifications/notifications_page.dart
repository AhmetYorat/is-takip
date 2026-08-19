import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/models/app_notification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/empty_state.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateChangesProvider).valueOrNull?.uid;
    if (uid == null) return const SizedBox.shrink();

    final notificationsAsync = ref.watch(notificationsProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: AsyncValueWidget<List<AppNotification>>(
        value: notificationsAsync,
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'Henüz bildiriminiz yok',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onTap: () async {
                  if (!notification.read) {
                    await ref
                        .read(firestoreServiceProvider)
                        .markNotificationRead(notification.id);
                  }
                  if (notification.jobId != null && context.mounted) {
                    context.push(AppRoutes.jobDetailPath(notification.jobId!));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notification.read ? Colors.transparent : scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: notification.read
                      ? textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        )
                      : textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatRelative(notification.createdAt),
                  style: textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
