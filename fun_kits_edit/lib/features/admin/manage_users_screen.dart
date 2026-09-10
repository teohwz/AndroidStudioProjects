import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/redemption_model.dart';
import '../../core/services/firestore_service.dart';

// Deliberately excludes 'exhibitor': an exhibitor account is only ever
// created via invite-code redemption (which also assigns a boothId) — this
// generic dropdown must never be able to set a user's role TO 'exhibitor',
// since that would leave them with no assigned booth and break every
// exhibitor-only screen. Viewing an *existing* exhibitor's profile is
// handled separately by _UserDetailDialogState's read-only Role display.
const List<String> _kRoles = ['visitor', 'admin', 'super_admin'];

String _roleLabel(String role) {
  switch (role) {
    case 'super_admin':
      return 'Super Admin';
    case 'admin':
      return 'Admin';
    case 'exhibitor':
      return 'Exhibitor';
    default:
      return 'Visitor';
  }
}

/// Super Admin: search/list every user, view their profile + redemption
/// history, add/remove points, ban/unban, and change roles. Role changes
/// and points/status writes are only *offered* here — the real guard
/// against a normal user reaching any of this is AuthService.isSuperAdmin
/// gating the route (SuperAdminGuard) plus firestore.rules server-side.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _fs = FirestoreService();
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((u) {
      final name = (u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final uid = (u['uid'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || uid.contains(q);
    }).toList();
  }

  void _openDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => _UserDetailDialog(user: user, fs: _fs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Users 👥',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, email, or user ID',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fs.getAllUsersAdmin(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = _applyFilter(snap.data ?? []);
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No users match your search.',
                          style: TextStyle(color: AppColors.textMedium)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return _UserListTile(
                      user: u,
                      isSelf: u['uid'] == myUid,
                      onTap: () => _openDetail(u),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile(
      {required this.user, required this.isSelf, required this.onTap});
  final Map<String, dynamic> user;
  final bool isSelf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = (user['role'] as String?) ?? 'visitor';
    final status = (user['accountStatus'] as String?) ?? 'active';
    final banned = status == 'banned';
    final points = (user['points'] as num?)?.toInt() ?? 0;
    final name = (user['displayName'] as String?)?.trim();
    final email = (user['email'] as String?)?.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (name != null && name.isNotEmpty)
                          ? name
                          : (email ?? 'Anonymous player'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(email != null && email.isNotEmpty ? email : 'No email',
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 11)),
                    Text('$points pts',
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Badge(
                    label: _roleLabel(role),
                    color: role == 'super_admin'
                        ? AppColors.accent
                        : role == 'admin'
                            ? AppColors.primary
                            : role == 'exhibitor'
                                ? AppColors.exhibitorColor
                                : AppColors.textMedium,
                  ),
                  const SizedBox(height: 4),
                  if (banned)
                    const _Badge(label: 'Banned', color: AppColors.danger)
                  else if (isSelf)
                    const _Badge(label: 'You', color: AppColors.success),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

class _UserDetailDialog extends StatefulWidget {
  const _UserDetailDialog({required this.user, required this.fs});
  final Map<String, dynamic> user;
  final FirestoreService fs;

  @override
  State<_UserDetailDialog> createState() => _UserDetailDialogState();
}

class _UserDetailDialogState extends State<_UserDetailDialog> {
  final _pointsCtrl = TextEditingController();
  bool _busy = false;
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = (widget.user['role'] as String?) ?? 'visitor';
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  String get _uid => widget.user['uid'] as String;

  Future<void> _adjustPoints(int sign) async {
    final raw = int.tryParse(_pointsCtrl.text.trim());
    if (raw == null || raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a positive number of points first.')));
      return;
    }
    setState(() => _busy = true);
    await widget.fs.adminAdjustUserPoints(_uid, raw * sign);
    if (mounted) {
      setState(() => _busy = false);
      _pointsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(sign > 0 ? 'Added $raw points.' : 'Removed $raw points.')));
    }
  }

  Future<void> _toggleBan(bool currentlyBanned) async {
    final action = currentlyBanned ? 'unban' : 'ban';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(currentlyBanned ? 'Unban this user?' : 'Ban this user?'),
        content: Text(currentlyBanned
            ? 'They will be able to sign in and play again.'
            : 'They will be blocked from using the app until unbanned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      currentlyBanned ? AppColors.success : AppColors.danger),
              child: Text(currentlyBanned ? 'Unban' : 'Ban')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await widget.fs
        .setUserStatus(_uid, currentlyBanned ? 'active' : 'banned');
    if (mounted) setState(() => _busy = false);
    // Note: action taken; leave dialog open so the admin can see the
    // updated badge state next time they reopen it, or close manually.
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmRoleChange() async {
    final newRole = _role;
    final oldRole = (widget.user['role'] as String?) ?? 'visitor';
    if (newRole == oldRole) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Highly privileged action'),
        content: Text(
          newRole == 'super_admin'
              ? 'You are about to grant SUPER ADMIN — the highest access '
                  'level in this app, including managing rewards, points, '
                  'and every other user. Are you sure?'
              : 'Change this user\'s role from ${_roleLabel(oldRole)} to '
                  '${_roleLabel(newRole)}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) {
      setState(() => _role = oldRole);
      return;
    }
    setState(() => _busy = true);
    await widget.fs.setUserRole(_uid, newRole);
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to ${_roleLabel(newRole)}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final status = (u['accountStatus'] as String?) ?? 'active';
    final banned = status == 'banned';
    final points = (u['points'] as num?)?.toInt() ?? 0;
    final name = (u['displayName'] as String?)?.trim();
    final email = (u['email'] as String?)?.trim();

    return AlertDialog(
      title: Text(
        (name != null && name.isNotEmpty)
            ? name
            : (email ?? 'Anonymous player'),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('User ID', _uid),
            _row('Email', email != null && email.isNotEmpty ? email : '—'),
            _row('Points', '$points'),
            _row('Status', banned ? 'Banned' : 'Active'),
            const SizedBox(height: 14),
            const Text('Adjust Points',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Amount',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : () => _adjustPoints(1),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.success),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: _busy ? null : () => _adjustPoints(-1),
                  icon: const Icon(Icons.remove_rounded),
                  style:
                      IconButton.styleFrom(backgroundColor: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Account Status',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _toggleBan(banned),
                icon: Icon(
                    banned ? Icons.lock_open_rounded : Icons.block_rounded,
                    size: 16,
                    color: banned ? AppColors.success : AppColors.danger),
                label: Text(banned ? 'Unban User' : 'Ban User',
                    style: TextStyle(
                        color: banned ? AppColors.success : AppColors.danger)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: banned ? AppColors.success : AppColors.danger)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Role',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            if (_role == 'exhibitor')
              // Exhibitor accounts are created only via invite-code
              // redemption, which also links them to one specific booth
              // (boothId). This generic Role control can't safely change
              // that — reassigning it here would leave the account's
              // booth link dangling — so it's shown read-only instead of
              // as an editable dropdown. See the _kRoles comment above.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.exhibitorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.exhibitorColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 16, color: AppColors.exhibitorColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (u['boothId'] as String?)?.isNotEmpty == true
                            ? 'Exhibitor — booth "${u['boothId']}"'
                            : 'Exhibitor',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.exhibitorColor),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _role,
                isExpanded: true,
                decoration: const InputDecoration(
                    isDense: true, border: OutlineInputBorder()),
                items: _kRoles
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _role = v);
                        _confirmRoleChange();
                      },
              ),
            const SizedBox(height: 16),
            const Text('Redemption History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            StreamBuilder<List<RedemptionModel>>(
              stream: widget.fs.getUserRedemptions(_uid),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                if (list.isEmpty) {
                  return const Text('No redemptions yet.',
                      style: TextStyle(
                          color: AppColors.textMedium, fontSize: 12));
                }
                return Column(
                  children: list
                      .take(10)
                      .map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${r.rewardName} (${r.pointsSpent} pts)',
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text(r.statusLabel,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMedium)),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textMedium, fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      );
}
