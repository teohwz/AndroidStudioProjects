import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/brand_styles.dart';
import '../../core/models/reward_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_palette.dart';

/// Super Admin: create/edit/deactivate/delete rewards, including their
/// brand logo and voucher image. This is the ONLY place reward metadata
/// changes — stock changes only ever happen in ManageInventoryScreen or
/// automatically via a redemption, never here (see RewardModel.toUpdateMap).
class ManageRewardsScreen extends StatefulWidget {
  const ManageRewardsScreen({super.key, this.openCreateOnLoad = false});

  final bool openCreateOnLoad;

  @override
  State<ManageRewardsScreen> createState() => _ManageRewardsScreenState();
}

class _ManageRewardsScreenState extends State<ManageRewardsScreen> {
  final _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnLoad) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showRewardDialog());
    }
  }

  void _showRewardDialog([RewardModel? existing]) {
    showDialog(
      context: context,
      builder: (_) => _RewardFormDialog(fs: _fs, existing: existing),
    );
  }

  static const List<RewardModel> _demoCatalogue = [
    RewardModel(id: '', name: 'Grab RM5 E-Voucher', brandName: 'Grab', voucherValue: 5, pointsRequired: 50, stock: 20),
    RewardModel(id: '', name: 'Grab RM10 E-Voucher', brandName: 'Grab', voucherValue: 10, pointsRequired: 100, stock: 20),
    RewardModel(id: '', name: 'foodpanda RM5 E-Voucher', brandName: 'foodpanda', voucherValue: 5, pointsRequired: 50, stock: 20),
    RewardModel(id: '', name: 'foodpanda RM10 E-Voucher', brandName: 'foodpanda', voucherValue: 10, pointsRequired: 100, stock: 20),
    RewardModel(id: '', name: "Touch 'n Go eWallet RM5 Reload", brandName: "Touch 'n Go eWallet", voucherValue: 5, pointsRequired: 50, stock: 20),
    RewardModel(id: '', name: "Touch 'n Go eWallet RM10 Reload", brandName: "Touch 'n Go eWallet", voucherValue: 10, pointsRequired: 100, stock: 20),
    RewardModel(id: '', name: 'Shopee RM5 Voucher', brandName: 'Shopee', voucherValue: 5, pointsRequired: 50, stock: 20),
    RewardModel(id: '', name: 'Shopee RM10 Voucher', brandName: 'Shopee', voucherValue: 10, pointsRequired: 100, stock: 20),
    RewardModel(id: '', name: 'Watsons RM10 Voucher', brandName: 'Watsons', voucherValue: 10, pointsRequired: 100, stock: 15),
    RewardModel(id: '', name: 'AEON RM10 Voucher', brandName: 'AEON', voucherValue: 10, pointsRequired: 100, stock: 15),
    RewardModel(id: '', name: "Lotus's RM10 Voucher", brandName: "Lotus's", voucherValue: 10, pointsRequired: 100, stock: 15),
    RewardModel(id: '', name: 'Tealive RM5 Voucher', brandName: 'Tealive', voucherValue: 5, pointsRequired: 50, stock: 25),
    RewardModel(id: '', name: 'ZUS Coffee RM5 Voucher', brandName: 'ZUS Coffee', voucherValue: 5, pointsRequired: 50, stock: 25),
  ];

  Future<void> _seedDemoCatalogue(bool alreadyHasRewards) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seed demo catalogue?'),
        content: Text(alreadyHasRewards
            ? 'This adds the ${_demoCatalogue.length} example Malaysian '
                'e-voucher rewards from the spec on top of what you already '
                'have (it will not touch or duplicate-check existing '
                'rewards by name). Placeholder brand tiles are used until '
                'you upload real images. Continue?'
            : 'Add ${_demoCatalogue.length} example Malaysian e-voucher '
                'rewards (Grab, foodpanda, Touch \'n Go eWallet, Shopee, '
                'Watsons, AEON, Lotus\'s, Tealive, ZUS Coffee) with '
                'placeholder brand tiles as demo starter data?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Seed')),
        ],
      ),
    );
    if (ok != true) return;
    for (final reward in _demoCatalogue) {
      await _fs.addReward(reward);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added ${_demoCatalogue.length} demo rewards.')));
    }
  }

  void _confirmDelete(RewardModel reward) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete reward?'),
        content: Text(
            'Delete "${reward.name}"? This cannot be undone. Consider deactivating instead if you might bring it back.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _fs.deleteReward(reward.id);
            },
            child: Text('Delete', style: TextStyle(color: palette.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Rewards',
            style: TextStyle(fontWeight: FontWeight.w800)),
        // Fixed "Ink" background — Super Admin screens keep a distinctly
        // dark app bar in both themes (see super_admin_dashboard_screen.dart).
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<List<RewardModel>>(
            stream: _fs.getAllRewardsAdmin(),
            builder: (context, snap) {
              final hasRewards = (snap.data ?? []).isNotEmpty;
              return IconButton(
                tooltip: 'Seed Demo Catalogue',
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: () => _seedDemoCatalogue(hasRewards),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRewardDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Reward',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<RewardModel>>(
        stream: _fs.getAllRewardsAdmin(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rewards = snap.data ?? [];
          if (rewards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No rewards yet.',
                        style: TextStyle(color: palette.textMedium)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _seedDemoCatalogue(false),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Seed Demo Catalogue'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: rewards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final reward = rewards[i];
              return _RewardAdminCard(
                reward: reward,
                onEdit: () => _showRewardDialog(reward),
                onDelete: () => _confirmDelete(reward),
                onToggleActive: (v) => _fs.setRewardActive(reward.id, v),
              );
            },
          );
        },
      ),
    );
  }
}

class _RewardAdminCard extends StatelessWidget {
  const _RewardAdminCard({
    required this.reward,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final RewardModel reward;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final style = brandStyleFor(reward.brandName);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: reward.brandImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: reward.brandImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          color: style.color.withOpacity(0.18),
                          alignment: Alignment.center,
                          child: Text(style.emoji)),
                    )
                  : Container(
                      color: style.color.withOpacity(0.18),
                      alignment: Alignment.center,
                      child:
                          Text(style.emoji, style: const TextStyle(fontSize: 22)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                    '${reward.brandName} · RM${reward.voucherValue} · ${reward.pointsRequired} pts',
                    style: TextStyle(color: palette.textMedium, fontSize: 12)),
                const SizedBox(height: 4),
                Text('Stock: ${reward.stock}  ·  ${reward.category}',
                    style: TextStyle(color: palette.textMedium, fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Switch(
                      value: reward.isActive,
                      onChanged: onToggleActive,
                    ),
                    Text(reward.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: reward.isActive
                                ? palette.success
                                : palette.textMedium)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon:
                    Icon(Icons.delete_outline, size: 20, color: palette.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Create/Edit form ──────────────────────────────────────────────────────
class _RewardFormDialog extends StatefulWidget {
  const _RewardFormDialog({required this.fs, this.existing});
  final FirestoreService fs;
  final RewardModel? existing;

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _storage = StorageService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _description;
  late final TextEditingController _value;
  late final TextEditingController _points;
  late final TextEditingController _stock;
  late final TextEditingController _category;
  bool _isActive = true;
  bool _saving = false;
  bool _uploadingBrand = false;
  bool _uploadingReward = false;
  String _brandImageUrl = '';
  String _rewardImageUrl = '';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _brand = TextEditingController(text: e?.brandName ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _value = TextEditingController(text: e != null ? '${e.voucherValue}' : '');
    _points =
        TextEditingController(text: e != null ? '${e.pointsRequired}' : '');
    _stock = TextEditingController(text: e != null ? '${e.stock}' : '0');
    _category = TextEditingController(text: e?.category ?? 'E-Voucher');
    _isActive = e?.isActive ?? true;
    _brandImageUrl = e?.brandImageUrl ?? '';
    _rewardImageUrl = e?.rewardImageUrl ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _description.dispose();
    _value.dispose();
    _points.dispose();
    _stock.dispose();
    _category.dispose();
    super.dispose();
  }

  num _parseValue() {
    final raw = num.tryParse(_value.text.trim()) ?? 0;
    // Store whole-number RM amounts as int so the UI shows "RM5" not
    // "RM5.0" — RewardModel.voucherValue accepts either.
    return raw == raw.roundToDouble() ? raw.toInt() : raw;
  }

  Future<void> _pickBrandLogo() async {
    final brand = _brand.text.trim();
    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a brand name first.')));
      return;
    }
    setState(() => _uploadingBrand = true);
    final url = await _storage.pickAndUploadBrandLogo(brandName: brand);
    if (mounted) {
      setState(() {
        _uploadingBrand = false;
        if (url != null) _brandImageUrl = url;
      });
    }
  }

  Future<void> _pickRewardImage() async {
    final brand = _brand.text.trim();
    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a brand name first.')));
      return;
    }
    setState(() => _uploadingReward = true);
    final url = await _storage.pickAndUploadRewardImage(brandName: brand);
    if (mounted) {
      setState(() {
        _uploadingReward = false;
        if (url != null) _rewardImageUrl = url;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = RewardModel(
          id: widget.existing!.id,
          name: _name.text.trim(),
          brandName: _brand.text.trim(),
          brandImageUrl: _brandImageUrl,
          rewardImageUrl: _rewardImageUrl,
          description: _description.text.trim(),
          voucherValue: _parseValue(),
          pointsRequired: int.tryParse(_points.text.trim()) ?? 0,
          stock: widget.existing!.stock, // unchanged — see toUpdateMap()
          category: _category.text.trim().isEmpty
              ? 'E-Voucher'
              : _category.text.trim(),
          isActive: _isActive,
        );
        await widget.fs.updateReward(updated);
      } else {
        final created = RewardModel(
          id: '',
          name: _name.text.trim(),
          brandName: _brand.text.trim(),
          brandImageUrl: _brandImageUrl,
          rewardImageUrl: _rewardImageUrl,
          description: _description.text.trim(),
          voucherValue: _parseValue(),
          pointsRequired: int.tryParse(_points.text.trim()) ?? 0,
          stock: int.tryParse(_stock.text.trim()) ?? 0,
          category: _category.text.trim().isEmpty
              ? 'E-Voucher'
              : _category.text.trim(),
          isActive: _isActive,
        );
        await widget.fs.addReward(created);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Reward' : 'New Reward',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Reward Name *',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                _field(_brand, 'Brand Name *',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                _field(_description, 'Description', maxLines: 2),
                Row(
                  children: [
                    Expanded(
                      child: _field(_value, 'Voucher Value (RM) *',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              num.tryParse(v?.trim() ?? '') == null
                                  ? 'Number required'
                                  : null),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_points, 'Points Required *',
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              int.tryParse(v?.trim() ?? '') == null
                                  ? 'Number required'
                                  : null),
                    ),
                  ],
                ),
                if (!_isEdit)
                  _field(_stock, 'Initial Stock *',
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v?.trim() ?? '') == null
                          ? 'Number required'
                          : null)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: palette.textMedium),
                        const SizedBox(width: 6),
                        Text('Stock: ${widget.existing!.stock} '
                            '(change it from Manage Inventory)',
                            style: TextStyle(
                                fontSize: 11, color: palette.textMedium)),
                      ],
                    ),
                  ),
                _field(_category, 'Category'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingBrand ? null : _pickBrandLogo,
                        icon: _uploadingBrand
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(
                                _brandImageUrl.isEmpty
                                    ? Icons.image_outlined
                                    : Icons.check_circle_rounded,
                                size: 16,
                                color: _brandImageUrl.isEmpty
                                    ? null
                                    : palette.success),
                        label: Text('Brand Logo',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploadingReward ? null : _pickRewardImage,
                        icon: _uploadingReward
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(
                                _rewardImageUrl.isEmpty
                                    ? Icons.photo_outlined
                                    : Icons.check_circle_rounded,
                                size: 16,
                                color: _rewardImageUrl.isEmpty
                                    ? null
                                    : palette.success),
                        label: Text('Voucher Image',
                            style: const TextStyle(fontSize: 12)),
),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
