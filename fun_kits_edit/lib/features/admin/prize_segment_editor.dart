import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';

const _uuid = Uuid();

/// Shared prize-pool editor used by both the Spin Wheel and Scratch Card
/// admin screens — each prize is independently a flat points award or a
/// limited-stock physical prize, with a relative win-probability weight.
/// Stateless: the parent screen owns the [segments] list and gets a full
/// replacement list back via [onChanged] whenever one is added/edited/removed.
class PrizeSegmentList extends StatelessWidget {
  const PrizeSegmentList({
    super.key,
    required this.segments,
    required this.onChanged,
    required this.accentColor,
  });

  final List<PrizeSegment> segments;
  final ValueChanged<List<PrizeSegment>> onChanged;
  final Color accentColor;

  Future<void> _addOrEdit(BuildContext context, [PrizeSegment? existing]) async {
    final result = await showModalBottomSheet<PrizeSegment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _SegmentFormSheet(existing: existing, accentColor: accentColor),
    );
    if (result == null) return;
    final updated = List<PrizeSegment>.from(segments);
    final i = updated.indexWhere((s) => s.id == result.id);
    if (i >= 0) {
      updated[i] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  void _remove(PrizeSegment s) {
    onChanged(segments.where((x) => x.id != s.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Prizes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            TextButton.icon(
              onPressed: () => _addOrEdit(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Prize'),
            ),
          ],
        ),
        if (segments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No prizes yet — add at least one so visitors can win '
              'something when they play.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
        for (final s in segments)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBg),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      s.isPoints
                          ? Icons.stars_rounded
                          : Icons.card_giftcard_rounded,
                      color: accentColor,
                      size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        s.isPoints
                            ? '${s.pointsValue} points · weight ${s.weight.toStringAsFixed(1)}'
                            : '${s.remainingStock}/${s.stock} left · weight ${s.weight.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textMedium),
                  onPressed: () => _addOrEdit(context, s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.danger),
                  onPressed: () => _remove(s),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SegmentFormSheet extends StatefulWidget {
  const _SegmentFormSheet({this.existing, required this.accentColor});
  final PrizeSegment? existing;
  final Color accentColor;

  @override
  State<_SegmentFormSheet> createState() => _SegmentFormSheetState();
}

class _SegmentFormSheetState extends State<_SegmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _valueCtrl; // pointsValue or stock, contextual
  late final TextEditingController _weightCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _type = e?.type ?? 'points';
    _valueCtrl = TextEditingController(
        text: e == null ? '' : (e.isPoints ? '${e.pointsValue}' : '${e.stock}'));
    _weightCtrl = TextEditingController(text: '${e?.weight ?? 1}');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final value = int.tryParse(_valueCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 1;
    final segment = PrizeSegment(
      id: widget.existing?.id ?? _uuid.v4(),
      label: _labelCtrl.text.trim(),
      type: _type,
      pointsValue: _type == 'points' ? value.clamp(1, 100000) : 0,
      stock: _type == 'physical' ? value.clamp(1, 100000) : 0,
      remainingStock: _type == 'physical' ? value.clamp(1, 100000) : 0,
      weight: weight <= 0 ? 1 : weight,
      colorHex: widget.existing?.colorHex ?? '',
    );
    Navigator.pop(context, segment);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.existing == null ? 'Add Prize' : 'Edit Prize',
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Prize name',
                      hintText: 'e.g. Free T-Shirt or 50 Points'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'points',
                        label: Text('Points'),
                        icon: Icon(Icons.stars_rounded)),
                    ButtonSegment(
                        value: 'physical',
                        label: Text('Physical Prize'),
                        icon: Icon(Icons.card_giftcard_rounded)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _type == 'points'
                        ? 'Points awarded'
                        : 'Stock (quantity available)',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a number > 0';
                    return null;
                  },
                ),
                if (_type == 'physical' && widget.existing != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Changing stock resets remaining stock to this amount.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Win probability weight',
                    hintText: 'Higher = more likely (default 1)',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Save Prize',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
