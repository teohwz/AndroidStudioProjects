import 'package:flutter/material.dart';

import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/fun_button.dart';
import 'prize_segment_editor.dart';

/// Exhibitor-scoped — always edits [boothId]'s (the caller's own booth)
/// Spin Wheel content only. Branding (colors) comes from the booth's own
/// theme automatically, so there's nothing to set here beyond the prizes.
class ManageSpinWheelScreen extends StatefulWidget {
  const ManageSpinWheelScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageSpinWheelScreen> createState() => _ManageSpinWheelScreenState();
}

class _ManageSpinWheelScreenState extends State<ManageSpinWheelScreen> {
  final _fs = FirestoreService();
  List<PrizeSegment> _segments = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _fs.getSpinWheelConfig(widget.boothId);
    if (!mounted) return;
    setState(() {
      _segments = config?.segments ?? [];
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one prize before saving.')));
      return;
    }
    setState(() => _saving = true);
    await _fs.saveSpinWheelConfig(
      SpinWheelConfig(boothId: widget.boothId, segments: _segments),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Spin Wheel saved!'),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Spin Wheel',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.spinWheelColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                Text(
                  'Visitors spin to win one of the prizes below — the wheel '
                  'is themed automatically using your booth\'s colors and '
                  'logo. Each prize can be a flat points award or a '
                  'limited-stock physical item, with its own win chance.',
                  style: TextStyle(color: palette.textMedium, fontSize: 12),
                ),
                const SizedBox(height: 16),
                PrizeSegmentList(
                  segments: _segments,
                  accentColor: palette.spinWheelColor,
                  onChanged: (s) => setState(() => _segments = s),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FunButton(
                  label: 'Save Spin Wheel',
                  isLoading: _saving,
                  onPressed: _save,
                  gradient: LinearGradient(colors: [
                    palette.spinWheelColor,
                    const Color(0xFFFF8FB1),
                  ]),
                ),
              ),
            ),
    );
  }
}
