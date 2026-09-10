// ─── NOTIFICATION MODEL ─────────────────────────────────────────────────────
// A visitor's in-app notification inbox entry — created whenever they win a
// physical prize (Lucky Draw / Spin Wheel / Scratch Card) or successfully
// redeem a Rewards Shop voucher (see FirestoreService's _notifyUser helper).
// Persisted per-uid in Firestore so it survives app restarts/devices, unlike
// a one-off SnackBar. There is no real email backend in this app (see
// firestore.rules' header note) — the in-app notification IS the real,
// user-visible side of a "you won!" moment; a matching `email_log` doc is
// also written as a technical, not user-facing, simulated-email record.
class NotificationModel {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String type; // 'prize_win' | 'redemption'
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) =>
      NotificationModel(
        id: id,
        uid: map['uid'] ?? '',
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        type: map['type'] ?? 'prize_win',
        read: map['read'] ?? false,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'createdAt': createdAt,
      };
}
