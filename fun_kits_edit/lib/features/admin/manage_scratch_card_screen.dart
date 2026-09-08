import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/fun_button.dart';
import 'prize_segment_editor.dart';

/// Exhibitor-scoped — always edits [boothId]'s (the caller's own booth)
/// Scratch Card content: the image revealed underneath the scratch layer,
/// the message shown alongside the prize, and the same weighted prize-pool
/// model used by the Spin Wheel.
class ManageScratchCardScreen extends StatefulWidget {
  const ManageScratchCardScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageScratchCardScreen> createState() =>
      _ManageScratchCardScreenState();
}

class _ManageScratchCardScreenState extends State<ManageScratchCardScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  late final TextEditingController _messageCtrl;
  List<PrizeSegment> _segments = [];
  String _imageUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: 'You won!');
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _fs.getScratchCardConfig(widget.boothId);
    if (!mounted) return;
    setState(() {
      _segments = config?.segments ?? [];
      _imageUrl = config?.cardImageUrl ?? '';
      _messageCtrl.text = config?.revealMessage ?? 'You won!';
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);
    final url = await _storage.pickAndUploadScratchCardImage(
        exhibitorId: widget.boothId);
    if (url != null && mounted) setState(() => _imageUrl = url);
    if (mounted) setState(() => _uploadingImage = false);
  }

  Future<void> _save() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one prize before saving.')));
      return;
    }
    setState(() => _saving = true);
    await _fs.saveScratchCardConfig(
      ScratchCardConfig(
        boothId: widget.boothId,
        cardImageUrl: _imageUrl,
        revealMessage: _messageCtrl.text.trim().isEmpty
            ? 'You won!'
            : _messageCtrl.text.trim(),
        segments: _segments,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Scratch Card saved! 🪙')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scratch Card 🪙',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.scratchCardColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                const Text(
                  'Visitors scratch to reveal a prize underneath your card '
                  'image. Set the image, the message shown once revealed, '
                  'and the prize pool below.',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _uploadingImage ? null : _pickImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBg, width: 1.5),
                      image: _imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_imageUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _uploadingImage
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : _imageUrl.isEmpty
                            ? const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      color: AppColors.textMedium),
                                  SizedBox(height: 4),
                                  Text('Card Image',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMedium)),
                                ],
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: const Text('Change Card Image',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reveal message',
                    hintText: 'e.g. Congrats — you won!',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                PrizeSegmentList(
                  segments: _segments,
                  accentColor: AppColors.scratchCardColor,
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
                  label: 'Save Scratch Card',
                  isLoading: _saving,
                  onPressed: _save,
                  gradient: const LinearGradient(colors: [
                    AppColors.scratchCardColor,
                    Color(0xFFFFD37A),
                  ]),
                ),
              ),
            ),
    );
  }
}
