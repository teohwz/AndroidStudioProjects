import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Super Admin: one-tap CSV exports for a post-exhibition wrap-up report.
///
/// Three independent exports — Users, Redemptions, Booth Stats — each built
/// from a single Firestore read (`.first` on the existing admin streams,
/// not a new query). Each one offers two delivery methods:
///  - **Share** — hands the CSV to the OS share sheet via `share_plus`, the
///    same pattern already used for QR export in exhibitor_qr_screen.dart.
///  - **Save** — opens the device's native "Save As" dialog via `file_picker`
///    so the Super Admin can pick a real, visible folder (e.g. Downloads),
///    distinct from the share sheet above.
/// No new package is used for CSV generation itself — the text is hand-built.
///
/// Users and Redemptions can optionally be scoped to a date range
/// (registration date / redemption date respectively). Booth Stats is
/// always a full current snapshot — booths are set up once before the
/// event rather than accumulating over time, so a date filter there
/// wouldn't mean much for a wrap-up report.
class ReportsExportScreen extends StatefulWidget {
  const ReportsExportScreen({super.key});

  @override
  State<ReportsExportScreen> createState() => _ReportsExportScreenState();
}

class _ReportsExportScreenState extends State<ReportsExportScreen> {
  final _fs = FirestoreService();
  bool _busy = false;

  // ── CSV helpers ──────────────────────────────────────────────────────
  String _csvField(Object? value) {
    final s = (value ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }
    return s;
  }

  String _csvRow(List<Object?> fields) =>
      '${fields.map(_csvField).join(',')}\r\n';

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'exhibitor':
        return 'Exhibitor';
      case 'admin':
        return 'Admin';
      default:
        return 'Visitor';
    }
  }

  bool _inRange(DateTime? d, DateTimeRange? range) {
    if (range == null) return true; // no filter requested — include everyone
    if (d == null) return false; // filter requested but nothing to compare
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
        range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  // ── Date-range prompt ────────────────────────────────────────────────
  /// Asks whether this export should be scoped to a date range.
  /// `proceed: false` means the admin backed out entirely (don't export).
  /// `range: null` with `proceed: true` means "all time".
  Future<({bool proceed, DateTimeRange? range})> _resolveDateScope(
      String dateLabel) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter by date?'),
        content: Text('Export every record, or only those with a '
            '$dateLabel in a specific range?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'all'),
              child: const Text('All time')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'range'),
              child: const Text('Choose range')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') {
      return (proceed: false, range: null);
    }
    if (choice == 'all') return (proceed: true, range: null);

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range == null) return (proceed: false, range: null);
    return (proceed: true, range: range);
  }

  // ── Delivery ─────────────────────────────────────────────────────────
  /// Hands the CSV to the OS share sheet (send/print/save-to-cloud, etc.).
  Future<void> _shareCsv(String filename, String csv) async {
    final dir = await Directory.systemTemp.createTemp('funkits_export');
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Fun Kits export — $filename');
  }

  /// Opens the device's native "Save As" dialog so the Super Admin can pick
  /// a real, visible folder (e.g. Downloads) to save the CSV to — distinct
  /// from _shareCsv's OS share sheet above. A `null` result means the admin
  /// cancelled the dialog, which is not an error.
  Future<void> _saveCsvToDevice(String filename, String csv) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save export',
      fileName: filename,
      bytes: bytes,
    );
    if (savedPath == null) return; // admin cancelled the dialog
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $filename to your device.')));
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not generate that export — please try again.')));
  }

  // ── CSV builders (pure: Firestore data → CSV text) ──────────────────
  Future<String> _buildUsersCsv(DateTimeRange? range) async {
    final users = await _fs.getAllUsersAdmin().first;
    final buffer = StringBuffer();
    buffer.write(_csvRow([
      'Display Name',
      'Email',
      'Role',
      'Points',
      'Account Status',
      'Registered On',
    ]));
    for (final u in users) {
      final createdAt = (u['createdAt'] as dynamic)?.toDate() as DateTime?;
      if (!_inRange(createdAt, range)) continue;
      final banned = (u['accountStatus'] as String?) == 'banned';
      buffer.write(_csvRow([
        u['displayName'] ?? '',
        u['email'] ?? '',
        _roleLabel(u['role'] as String?),
        u['points'] ?? 0,
        banned ? 'Banned' : 'Active',
        _fmtDate(createdAt),
      ]));
    }
    return buffer.toString();
  }

  Future<String> _buildRedemptionsCsv(DateTimeRange? range) async {
    final redemptions = await _fs.getAllRedemptions().first;
    final buffer = StringBuffer();
    buffer.write(_csvRow([
      'Date',
      'User Email',
      'Reward Name',
      'Brand',
      'Voucher Value',
      'Points Spent',
      'Status',
      'Refunded',
    ]));
    for (final r in redemptions) {
      if (!_inRange(r.createdAt, range)) continue;
      buffer.write(_csvRow([
        _fmtDate(r.createdAt),
        r.accountEmail ?? '',
        r.rewardName,
        r.brandName,
        r.voucherValue,
        r.pointsSpent,
        r.statusLabel,
        r.refunded ? 'Yes' : 'No',
      ]));
    }
    return buffer.toString();
  }

  Future<String> _buildBoothsCsv() async {
    final booths = await _fs.getBoothsAdmin().first;
    final buffer = StringBuffer();
    buffer.write(_csvRow([
      'Booth Number',
      'Exhibitor Name',
      'Category',
      'Claimed',
      'Sponsored',
      'Set Up On',
    ]));
    for (final b in booths) {
      buffer.write(_csvRow([
        b.boothNumber,
        b.name,
        b.category,
        b.isClaimed ? 'Yes' : 'No',
        b.isSponsored ? 'Yes' : 'No',
        _fmtDate(b.createdAt),
      ]));
    }
    return buffer.toString();
  }

  // ── Exports (build + deliver) ────────────────────────────────────────
  Future<void> _deliver(String filename, String csv, {required bool share}) =>
      share ? _shareCsv(filename, csv) : _saveCsvToDevice(filename, csv);

  Future<void> _exportUsers({required bool share}) async {
    final scope = await _resolveDateScope('registration date');
    if (!scope.proceed) return;
    setState(() => _busy = true);
    try {
      final csv = await _buildUsersCsv(scope.range);
      await _deliver('funkits_users_${_timestamp()}.csv', csv, share: share);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportRedemptions({required bool share}) async {
    final scope = await _resolveDateScope('redemption date');
    if (!scope.proceed) return;
    setState(() => _busy = true);
    try {
      final csv = await _buildRedemptionsCsv(scope.range);
      await _deliver(
          'funkits_redemptions_${_timestamp()}.csv', csv, share: share);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBooths({required bool share}) async {
    setState(() => _busy = true);
    try {
      final csv = await _buildBoothsCsv();
      await _deliver('funkits_booths_${_timestamp()}.csv', csv, share: share);
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reports & Export',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Download a CSV of your event data — handy for a '
                'post-exhibition wrap-up report. Share it, or save it '
                'straight to your device.',
                style: TextStyle(fontSize: 12.5, color: palette.textMedium),
              ),
              const SizedBox(height: 16),
              _ExportTile(
                icon: Icons.groups_rounded,
                color: theme.colorScheme.primary,
                title: 'Export Users',
                subtitle: 'Name, email, role, points, status — optional '
                    'date-range filter by registration date.',
                busy: _busy,
                onShare: () => _exportUsers(share: true),
                onSave: () => _exportUsers(share: false),
              ),
              const SizedBox(height: 10),
              _ExportTile(
                icon: Icons.receipt_long_rounded,
                color: palette.quizColor,
                title: 'Export Redemptions',
                subtitle: 'Every redemption, its status and refund state — '
                    'optional date-range filter by redemption date.',
                busy: _busy,
                onShare: () => _exportRedemptions(share: true),
                onSave: () => _exportRedemptions(share: false),
              ),
              const SizedBox(height: 10),
              _ExportTile(
                icon: Icons.storefront_rounded,
                color: palette.exhibitorColor,
                title: 'Export Booth Stats',
                subtitle: 'Every booth, claimed status and category — '
                    'always a full current snapshot.',
                busy: _busy,
                onShare: () => _exportBooths(share: true),
                onSave: () => _exportBooths(share: false),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.15),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onShare,
    required this.onSave,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: palette.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 11, color: palette.textMedium)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onSave,
                  icon: const Icon(Icons.save_alt_rounded, size: 15),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
