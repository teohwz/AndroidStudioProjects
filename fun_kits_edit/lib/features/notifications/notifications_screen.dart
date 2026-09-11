import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/notification_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// A visitor's own notification inbox — prize wins and Rewards Shop
/// redemption confirmations (see FirestoreService's _notifyUser helper).
/// Reached via the bell icon on Home's app bar. Tapping an item marks it
/// read; there is no way to delete one (matches this app's existing
/// "immutable log" convention for game_sessions/booth_checkins/etc).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<NotificationModel>>(
              stream: fs.watchNotifications(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('No notifications yet.',
                            style: TextStyle(color: palette.textMedium)),
                        const SizedBox(height: 6),
                        Text(
                          "You'll be notified here if you win a prize or\n"
                          'redeem a voucher.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: palette.textMedium, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return Card(
                      elevation: n.read ? 0.5 : 2,
                      color: n.read
                          ? palette.cardBg.withOpacity(0.5)
                          : theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Icon(
                            n.type == 'redemption'
                                ? Icons.card_giftcard_rounded
                                : Icons.emoji_events_rounded,
                            size: 26,
                            color: theme.colorScheme.primary),
                        title: Text(n.title,
                            style: TextStyle(
                                fontWeight:
                                    n.read ? FontWeight.w600 : FontWeight.w800)),
                        subtitle: Text(n.body,
                            style: const TextStyle(fontSize: 12.5)),
                        onTap: () {
                          if (!n.read) fs.markNotificationRead(n.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
