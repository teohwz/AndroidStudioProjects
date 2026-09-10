import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/firestore_service.dart';

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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications 🔔',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
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
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔔', style: TextStyle(fontSize: 64)),
                        SizedBox(height: 12),
                        Text('No notifications yet.',
                            style: TextStyle(color: AppColors.textMedium)),
                        SizedBox(height: 6),
                        Text(
                          "You'll be notified here if you win a prize or\n"
                          'redeem a voucher.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMedium, fontSize: 12),
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
                          ? AppColors.cardBg.withOpacity(0.5)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Text(n.type == 'redemption' ? '🎁' : '🏆',
                            style: const TextStyle(fontSize: 26)),
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
