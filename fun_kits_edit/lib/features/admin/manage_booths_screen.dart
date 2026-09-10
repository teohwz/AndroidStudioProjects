import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

/// Super Admin manages booth SLOTS and invite codes only — never a booth's
/// customization or games (that's the owning exhibitor's job, enforced both
/// by this UI never offering it and by firestore.rules refusing the write).
/// See requirement #11: "Super Admin can manage all exhibitor booths only,
/// not game".
class ManageBoothsScreen extends StatefulWidget {
  const ManageBoothsScreen({super.key});

  @override
  State<ManageBoothsScreen> createState() => _ManageBoothsScreenState();
}

class _ManageBoothsScreenState extends State<ManageBoothsScreen> {
  final _fs = FirestoreService();

  void _createBoothSlot() {
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Booth Slot',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              decoration: const InputDecoration(
                  labelText: 'Booth Number *',
                  hintText: 'e.g. A-12',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name (optional — exhibitor can set later)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.exhibitorColor),
            onPressed: () async {
              final number = numberCtrl.text.trim();
              if (number.isEmpty) return;
              await _fs.createBoothSlot(
                  boothNumber: number, name: nameCtrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openInvites(ExhibitorModel booth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(fs: _fs, booth: booth),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Booths 🏪',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoothSlot,
        backgroundColor: AppColors.exhibitorColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Booth Slot',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<ExhibitorModel>>(
        stream: _fs.getBoothsAdmin(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final booths = snap.data ?? [];
          if (booths.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.store_outlined,
                    size: 64, color: AppColors.textMedium.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('No booth slots yet.',
                    style:
                        TextStyle(color: AppColors.textMedium, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Tap + to create one and generate an invite code.',
                    style: TextStyle(color: AppColors.textMedium)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: booths.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final b = booths[i];
              return _BoothTile(
                booth: b,
                onToggleActive: (v) => _fs.setBoothActive(b.id, v),
                onInvites: () => _openInvites(b),
              );
            },
          );
        },
      ),
    );
  }
}

class _BoothTile extends StatelessWidget {
  const _BoothTile(
      {required this.booth,
      required this.onToggleActive,
      required this.onInvites});

  final ExhibitorModel booth;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onInvites;

  @override
  Widget build(BuildContext context) {
    final color = booth.themeColor;
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Text(
              booth.name.isNotEmpty ? booth.name[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booth.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Booth ${booth.boothNumber}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: booth.isClaimed
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booth.isClaimed ? 'Claimed' : 'Unclaimed',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: booth.isClaimed
                            ? AppColors.success
                            : AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key_rounded, size: 20),
            tooltip: 'Invite codes',
            color: AppColors.exhibitorColor,
            onPressed: onInvites,
          ),
          Switch(
            value: booth.isActive,
            onChanged: onToggleActive,
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

/// A booth's invite code moves through three states: [active] (unused,
/// not yet expired — the one that blocks a new "Generate"), [used]
/// (redeemed by an exhibitor), or [expired] (7 days passed, unused).
enum _InviteState { active, used, expired }

_InviteState _inviteState(Map<String, dynamic> invite) {
  if (invite['used'] == true) return _InviteState.used;
  final expiresAt = invite['expiresAt'] as Timestamp?;
  if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
    return _InviteState.expired;
  }
  return _InviteState.active;
}

/// Relative time-remaining text for an Active invite only ("Expires in 6d
/// 23h" / "Expires in 3h 12m" / "Expires in 4m") — null for Used/Expired
/// codes, and for a legacy code with no `expiresAt` at all (it never
/// expires, so there's nothing to count down to). Computed fresh whenever
/// the invite list rebuilds — not a live per-second ticking timer.
String? _expiryCountdownText(Map<String, dynamic> invite) {
  if (_inviteState(invite) != _InviteState.active) return null;
  final expiresAt = invite['expiresAt'] as Timestamp?;
  if (expiresAt == null) return null;
  final remaining = expiresAt.toDate().difference(DateTime.now());
  if (remaining.isNegative) return null;
  if (remaining.inDays >= 1) {
    return 'Expires in ${remaining.inDays}d ${remaining.inHours % 24}h';
  }
  if (remaining.inHours >= 1) {
    return 'Expires in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
  }
  return 'Expires in ${remaining.inMinutes.clamp(1, 59)}m';
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.fs, required this.booth});
  final FirestoreService fs;
  final ExhibitorModel booth;

  Future<void> _generate(BuildContext context) async {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final code = await fs.generateExhibitorInvite(
        boothId: booth.id, createdByUid: uid);
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invite Code Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(code,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Give this code to the exhibitor. It can only be used once, '
                'for this booth, and expires in 7 days if unused.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollCtrl) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: fs.getInvitesForBooth(booth.id),
            builder: (context, snap) {
              final invites = snap.data ?? [];
              // Only one active (unused, unexpired) code is allowed per
              // booth at a time — Generate stays hidden until it's used
              // or expires.
              final hasActiveCode = invites
                  .any((inv) => _inviteState(inv) == _InviteState.active);
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Invite Codes — ${booth.name}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        if (!booth.isClaimed && !hasActiveCode)
                          TextButton.icon(
                            onPressed: () => _generate(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Generate'),
                          ),
                      ],
                    ),
                  ),
                  if (booth.isClaimed)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'This booth has already been claimed by an exhibitor — '
                        'no new codes are needed.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                    )
                  else if (hasActiveCode)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'There is already an active code for this booth — '
                        'it must be used or expire before a new one can be '
                        'generated.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                    ),
                  Expanded(
                    child: invites.isEmpty
                        ? const Center(
                            child: Text('No invite codes generated yet.',
                                style:
                                    TextStyle(color: AppColors.textMedium)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: invites.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final inv = invites[i];
                              final state = _inviteState(inv);
                              final String label;
                              final Color color;
                              switch (state) {
                                case _InviteState.active:
                                  label = 'Active';
                                  color = AppColors.success;
                                  break;
                                case _InviteState.used:
                                  label = 'Used';
                                  color = AppColors.textMedium;
                                  break;
                                case _InviteState.expired:
                                  label = 'Expired';
                                  color = AppColors.danger;
                                  break;
                              }
                              final countdown = _expiryCountdownText(inv);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(inv['code'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                subtitle: countdown == null
                                    ? null
                                    : Text(countdown,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMedium)),
                                trailing: Text(
                                  label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: color),
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
      ),
    );
  }
}
