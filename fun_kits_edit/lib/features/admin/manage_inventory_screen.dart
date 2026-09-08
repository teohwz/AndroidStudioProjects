import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/inventory_log_model.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/firestore_service.dart';

/// Super Admin: adjust stock (add/remove/correct) with a reason, and see
/// every past adjustment for a reward — the audit trail requirement 17
/// asks for. Redemption's automatic -1 is NOT logged here (that's routine
/// sales, not an "adjustment" — see FirestoreService.adjustStock).
class ManageInventoryScreen extends StatelessWidget {
  const ManageInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Inventory 📦',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _ThresholdBar(fs: fs),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<RewardModel>>(
              stream: fs.getAllRewardsAdmin(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rewards = snap.data ?? [];
                if (rewards.isEmpty) {
                  return const Center(
                      child: Text('No rewards yet.',
                          style: TextStyle(color: AppColors.textMedium)));
                }
                return StreamBuilder<int>(
                  stream: fs.getLowStockThreshold(),
                  builder: (context, thSnap) {
                    final threshold = thSnap.data ??
                        FirestoreService.defaultLowStockThreshold;
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rewards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _InventoryCard(
                          reward: rewards[i], threshold: threshold, fs: fs),
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

class _ThresholdBar extends StatefulWidget {
  const _ThresholdBar({required this.fs});
  final FirestoreService fs;

  @override
  State<_ThresholdBar> createState() => _ThresholdBarState();
}

class _ThresholdBarState extends State<_ThresholdBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: widget.fs.getLowStockThreshold(),
      builder: (context, snap) {
        final threshold =
            snap.data ?? FirestoreService.defaultLowStockThreshold;
        if (_ctrl.text.isEmpty) _ctrl.text = '$threshold';
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: AppColors.textMedium),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Low-stock threshold (stock ≤ this shows ⚠️)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final v = int.tryParse(_ctrl.text.trim());
                  if (v != null && v >= 0) {
                    await widget.fs.setLowStockThreshold(v);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Threshold updated')));
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard(
      {required this.reward, required this.threshold, required this.fs});
  final RewardModel reward;
  final int threshold;
  final FirestoreService fs;

  Color get _levelColor {
    switch (reward.stockLevel(threshold)) {
      case StockLevel.outOfStock:
        return AppColors.danger;
      case StockLevel.low:
        return AppColors.warning;
      case StockLevel.normal:
        return AppColors.success;
    }
  }

  String get _levelLabel {
    switch (reward.stockLevel(threshold)) {
      case StockLevel.outOfStock:
        return 'Out of Stock';
      case StockLevel.low:
        return 'Low Stock';
      case StockLevel.normal:
        return 'Normal';
    }
  }

  void _openAdjustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AdjustStockDialog(reward: reward, fs: fs),
    );
  }

  void _openHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InventoryHistorySheet(reward: reward, fs: fs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(reward.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_levelLabel,
                    style: TextStyle(
                        color: _levelColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Current Stock: ${reward.stock}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openAdjustDialog(context),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Adjust Stock',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openHistory(context),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label:
                      const Text('History', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustStockDialog extends StatefulWidget {
  const _AdjustStockDialog({required this.reward, required this.fs});
  final RewardModel reward;
  final FirestoreService fs;

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final delta = int.parse(_amount.text.trim());
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    await widget.fs.adjustStock(
      rewardId: widget.reward.id,
      delta: delta,
      reason: _reason.text.trim().isEmpty
          ? 'No reason given'
          : _reason.text.trim(),
      changedByUid: user?.uid ?? 'unknown',
      changedByLabel: (!(user?.isAnonymous ?? true))
          ? (user?.email ?? 'Super Admin')
          : 'Super Admin',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Stock — ${widget.reward.name}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${widget.reward.stock}',
                style: const TextStyle(color: AppColors.textMedium)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Adjustment (e.g. 10 or -3) *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null) return 'Enter a whole number (+ or -)';
                if (widget.reward.stock + n < 0) {
                  return 'Would make stock negative';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (e.g. Restocking)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Apply'),
        ),
      ],
    );
  }
}

class _InventoryHistorySheet extends StatelessWidget {
  const _InventoryHistorySheet({required this.reward, required this.fs});
  final RewardModel reward;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) => Column(
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
            padding: const EdgeInsets.all(16),
            child: Text('Inventory History — ${reward.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryLogModel>>(
              stream: fs.getInventoryLogs(rewardId: reward.id),
              builder: (context, snap) {
                final logs = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (logs.isEmpty) {
                  return const Center(
                      child: Text('No adjustments logged yet.',
                          style: TextStyle(color: AppColors.textMedium)));
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    final positive = log.adjustment >= 0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          positive
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color:
                              positive ? AppColors.success : AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${positive ? '+' : ''}${log.adjustment}  (${log.previousStock} → ${log.newStock})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(log.reason,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium)),
                              Text(
                                  'By ${log.changedByLabel}'
                                  '${log.createdAt != null ? ' · ${log.createdAt!.day}/${log.createdAt!.month}/${log.createdAt!.year}' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                      ],
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
