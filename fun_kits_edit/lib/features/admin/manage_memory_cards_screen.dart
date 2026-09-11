import 'package:flutter/material.dart';

import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/fun_button.dart';

/// Exhibitor-scoped — always edits [boothId]'s (the caller's own booth)
/// Memory Cards pair images. Points reward stays on the existing Game
/// Settings screen's flat enable/points config — this screen only sets how
/// many pairs (4/6/8) and which image represents each one.
class ManageMemoryCardsScreen extends StatefulWidget {
  const ManageMemoryCardsScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageMemoryCardsScreen> createState() =>
      _ManageMemoryCardsScreenState();
}

class _ManageMemoryCardsScreenState extends State<ManageMemoryCardsScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  int _pairCount = 6;
  List<String> _pairImages = [];
  bool _loading = true;
  bool _saving = false;
  int? _uploadingIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _fs.getMemoryPairsConfig(widget.boothId);
    if (!mounted) return;
    setState(() {
      if (config != null && config.pairImageUrls.isNotEmpty) {
        _pairCount = config.pairImageUrls.length;
        _pairImages = List.from(config.pairImageUrls);
      } else {
        _pairImages = List.filled(_pairCount, '');
      }
      _loading = false;
    });
  }

  void _setPairCount(int count) {
    setState(() {
      _pairCount = count;
      final resized = List<String>.filled(count, '');
      for (var i = 0; i < count && i < _pairImages.length; i++) {
        resized[i] = _pairImages[i];
      }
      _pairImages = resized;
    });
  }

  Future<void> _pickImage(int index) async {
    setState(() => _uploadingIndex = index);
    final url = await _storage.pickAndUploadMemoryPairImage(
        exhibitorId: widget.boothId);
    if (url != null && mounted) {
      setState(() => _pairImages[index] = url);
    }
    if (mounted) setState(() => _uploadingIndex = null);
  }

  bool get _allImagesSet =>
      _pairImages.length == _pairCount && _pairImages.every((u) => u.isNotEmpty);

  Future<void> _save() async {
    if (!_allImagesSet) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload all $_pairCount pair images before saving.')));
      return;
    }
    setState(() => _saving = true);
    await _fs.saveMemoryPairsConfig(
      MemoryPairsConfig(boothId: widget.boothId, pairImageUrls: _pairImages),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Memory Cards saved!'),
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
        title: const Text('Memory Cards',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.exhibitorColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                Text(
                  'Visitors flip tiles to find matching pairs of YOUR '
                  'images — a fun way to get your products or branding in '
                  'front of them. Points reward is set on the Game '
                  'Settings screen.',
                  style: TextStyle(color: palette.textMedium, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 4, label: Text('4 pairs')),
                    ButtonSegment(value: 6, label: Text('6 pairs')),
                    ButtonSegment(value: 8, label: Text('8 pairs')),
                  ],
                  selected: {_pairCount},
                  onSelectionChanged: (s) => _setPairCount(s.first),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pairCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, i) {
                    final url = _pairImages.length > i ? _pairImages[i] : '';
                    final uploading = _uploadingIndex == i;
                    return InkWell(
                      onTap: uploading ? null : () => _pickImage(i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.cardBg, width: 1.5),
                          image: url.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(url), fit: BoxFit.cover)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: uploading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : url.isEmpty
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded,
                                          color: palette.textMedium, size: 20),
                                      const SizedBox(height: 2),
                                      Text('Pair ${i + 1}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: palette.textMedium)),
                                    ],
                                  )
                                : null,
                      ),
                    );
                  },
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FunButton(
                  label: 'Save Memory Cards',
                  isLoading: _saving,
                  onPressed: _save,
                  gradient: LinearGradient(colors: [
                    palette.exhibitorColor,
                    const Color(0xFF6EE7A8),
                  ]),
                ),
              ),
            ),
    );
  }
}
