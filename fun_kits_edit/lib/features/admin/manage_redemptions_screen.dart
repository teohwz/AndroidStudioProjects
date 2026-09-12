import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/redemption_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Super Admin: view every redemption, search/filter by user, email,
/// reward, brand, status, or date, change status, and cancel+refund with a
/// guard against double refunds (see FirestoreService.cancelAndRefundRedemption).
class ManageRedemptionsScreen extends StatefulWidget {
  const ManageRedemptionsScreen({super.key});

  @override
  State<ManageRedemptionsScreen> createState() =>
      _ManageRedemptionsScreenState();
}

class _ManageRedemptionsScreenState extends State<ManageRedemptionsScreen> {
  final _fs = FirestoreService();
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RedemptionModel> _applyFilters(List<RedemptionModel> all) {
    return all.where((r) {
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (_dateRange != null && r.createdAt != null) {
        final d = r.createdAt!;
        final afterStart = !d.isBefore(_dateRange!.start);
        final beforeEnd =
            d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        if (!afterStart || !beforeEnd) return false;
      }
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      return r.userId.toLowerCase().contains(q) ||
          (r.accountEmail ?? '').toLowerCase().contains(q) ||
          r.deliveryEmail.toLowerCase().contains(q) ||
          r.rewardName.toLowerCase().contains(q) ||
          r.brandName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _openDetail(RedemptionModel r) {
    showDialog(
      context: context,
      builder: (_) => _RedemptionDetailDialog(redemption: r, fs: _fs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Redemptions',
            style: TextStyle(fontWeight: FontWeight.w800)),
        // Fixed "Ink" background — Super Admin screens keep a distinctly
        // dark app bar in both themes (see super_admin_dashboard_screen.dart).
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search user, email, reward, or brand',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            isDense: true, border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('All statuses')),
                          ...RedemptionStatus.all.map((s) => DropdownMenuItem(
                              value: s, child: Text(redemptionStatusLabel(s)))),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(_dateRange == null ? 'Date' : 'Filtered',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    if (_dateRange != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _dateRange = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<RedemptionModel>>(
              stream: _fs.getAllRedemptions(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = _applyFilters(snap.data ?? []);
                if (filtered.isEmpty) {
                  return Center(
                      child: Text('No redemptions match your filters.',
                          style: TextStyle(color: palette.textMedium)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    return _RedemptionListTile(
                        r: r, onTap: () => _openDetail(r));
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

Color _statusColor(String status, AppPalette palette, Color primary) {
  switch (status) {
    case RedemptionStatus.delivered:
      return palette.success;
    case RedemptionStatus.processing:
      return palette.warning;
    case RedemptionStatus.cancelled:
    case RedemptionStatus.refunded:
      return palette.danger;
    default:
      return primary;
  }
}

class _RedemptionListTile extends StatelessWidget {
  const _RedemptionListTile({required this.r, required this.onTap});
  final RedemptionModel r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = _statusColor(r.status, palette, theme.colorScheme.primary);
    return Material(
      color: theme.colorScheme.surface,
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
                    Text(r.rewardName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('${r.brandName} · RM${r.voucherValue} · ${r.pointsSpent} pts',
                        style: TextStyle(color: palette.textMedium, fontSize: 11)),
                    Text(r.deliveryEmail,
                        style: TextStyle(color: palette.textMedium, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.statusLabel,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedemptionDetailDialog extends StatefulWidget {
  const _RedemptionDetailDialog({required this.redemption, required this.fs});
  final RedemptionModel redemption;
  final FirestoreService fs;

  @override
  State<_RedemptionDetailDialog> createState() =>
      _RedemptionDetailDialogState();
}

class _RedemptionDetailDialogState extends State<_RedemptionDetailDialog> {
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.redemption.status;
  }

  Future<void> _applyStatus() async {
    setState(() => _busy = true);
    await widget.fs.updateRedemptionStatus(widget.redemption.id, _status);
    if (mounted) {
      setState(() => _busy = false);
      Navigator.pop(context);
    }
  }

  Future<void> _confirmRefund() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel & Refund?'),
        content: Text(
            'This refunds ${widget.redemption.pointsSpent} points to the '
            'user and restores 1 unit of stock. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refund')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final outcome =
          await widget.fs.cancelAndRefundRedemption(widget.redemption.id);
      if (!mounted) return;
      setState(() => _busy = false);
      if (outcome.success) {
        Navigator.pop(context);
      } else {
        final msg = outcome.failureReason == 'already_refunded'
            ? 'This redemption was already refunded — it cannot be refunded again.'
            : 'Could not refund this redemption.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      // Defensive: cancelAndRefundRedemption() already isolates its own
      // notify-the-visitor step so it can't throw from here (see that
      // method's comment), but this still guards against any other
      // unexpected failure leaving _busy stuck forever with no visible
      // feedback — same "must not fail silently" fix already applied to
      // shop_screen.dart's redeem flow earlier this session.
      debugPrint('_confirmRefund: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong — please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.redemption;
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AlertDialog(
      title: Text(r.rewardName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Redemption ID', r.id),
            _row('User ID', r.userId),
            _row('Account Email', r.accountEmail ?? '(anonymous)'),
            _row('Delivery Email', r.deliveryEmail),
            _row('Brand', r.brandName),
            _row('Voucher Value', 'RM${r.voucherValue}'),
            _row('Points Spent', '${r.pointsSpent}'),
            if (r.createdAt != null)
              _row('Redeemed',
                  '${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}'),
            const SizedBox(height: 14),
            const Text('Status',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: RedemptionStatus.all
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(redemptionStatusLabel(s))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 14),
            if (r.refunded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: palette.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Already refunded — cannot be refunded again.',
                        style: TextStyle(
                            color: palette.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _confirmRefund,
                  icon: Icon(Icons.undo_rounded, size: 16, color: palette.danger),
                  label: Text('Cancel & Refund',
                      style: TextStyle(color: palette.danger)),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.danger)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton(
          onPressed: _busy ? null : _applyStatus,
          child: const Text('Save Status'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).extension<AppPalette>()!.textMedium,
                      fontSize: 11)),
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
