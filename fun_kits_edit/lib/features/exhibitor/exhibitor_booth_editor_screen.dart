import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';

/// An exhibitor's own booth customization form — name, logo, banner,
/// colors, background, welcome message, description. Everything here is
/// scoped to their OWN booth only (the caller always passes their own
/// boothId; there's no way to open this for someone else's booth from the
/// UI, and firestore.rules refuses the write server-side regardless).
class ExhibitorBoothEditorScreen extends StatefulWidget {
  const ExhibitorBoothEditorScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ExhibitorBoothEditorScreen> createState() =>
      _ExhibitorBoothEditorScreenState();
}

class _ExhibitorBoothEditorScreenState
    extends State<ExhibitorBoothEditorScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _formKey = GlobalKey<FormState>();

  bool _initialized = false;
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _uploadingBanner = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _welcomeCtrl;
  String _logoUrl = '';
  String _bannerUrl = '';
  Color _primary = AppColors.primary;
  Color _secondary = AppColors.secondary;
  Color _background = AppColors.backgroundLight;

  ExhibitorModel? _current;

  void _initFromBooth(ExhibitorModel booth) {
    if (_initialized) return;
    _current = booth;
    _nameCtrl = TextEditingController(text: booth.name);
    _descCtrl = TextEditingController(text: booth.description);
    _emailCtrl = TextEditingController(text: booth.contactEmail);
    _phoneCtrl = TextEditingController(text: booth.contactPhone);
    _websiteCtrl = TextEditingController(text: booth.website);
    _welcomeCtrl = TextEditingController(text: booth.welcomeMessage);
    _logoUrl = booth.logoUrl;
    _bannerUrl = booth.bannerImageUrl;
    _primary = booth.themeColor;
    _secondary = booth.secondaryColor;
    _background = booth.backgroundColor;
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameCtrl.dispose();
      _descCtrl.dispose();
      _emailCtrl.dispose();
      _phoneCtrl.dispose();
      _websiteCtrl.dispose();
      _welcomeCtrl.dispose();
    }
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _pickColor(Color initial, ValueChanged<Color> onChanged) async {
    Color temp = initial;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onChanged(temp);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadLogo() async {
    setState(() => _uploadingLogo = true);
    final url =
        await _storage.pickAndUploadLogo(exhibitorId: widget.boothId);
    if (url != null && mounted) setState(() => _logoUrl = url);
    if (mounted) setState(() => _uploadingLogo = false);
  }

  Future<void> _uploadBanner() async {
    setState(() => _uploadingBanner = true);
    final url =
        await _storage.pickAndUploadBanner(exhibitorId: widget.boothId);
    if (url != null && mounted) setState(() => _bannerUrl = url);
    if (mounted) setState(() => _uploadingBanner = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _current == null) return;
    setState(() => _saving = true);
    final updated = _current!.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      welcomeMessage: _welcomeCtrl.text.trim(),
      themeColorHex: _toHex(_primary),
      secondaryColorHex: _toHex(_secondary),
      backgroundColorHex: _toHex(_background),
      logoUrl: _logoUrl,
      bannerImageUrl: _bannerUrl,
    );
    await _fs.updateBoothCustomization(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booth saved ✅')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Customize My Booth 🎨',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ExhibitorModel?>(
        stream: _fs.watchExhibitor(widget.boothId),
        builder: (context, snap) {
          if (!snap.hasData && !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasData && snap.data != null) {
            _initFromBooth(snap.data!);
          }
          if (!_initialized) {
            return const Center(child: Text('Booth not found.'));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Images'),
                Row(
                  children: [
                    Expanded(
                      child: _ImageTile(
                        label: 'Logo',
                        url: _logoUrl,
                        uploading: _uploadingLogo,
                        onTap: _uploadLogo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ImageTile(
                        label: 'Banner',
                        url: _bannerUrl,
                        uploading: _uploadingBanner,
                        onTap: _uploadBanner,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('Colors'),
                Row(
                  children: [
                    Expanded(
                      child: _ColorTile(
                        label: 'Primary',
                        color: _primary,
                        onTap: () =>
                            _pickColor(_primary, (c) => setState(() => _primary = c)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ColorTile(
                        label: 'Secondary',
                        color: _secondary,
                        onTap: () => _pickColor(
                            _secondary, (c) => setState(() => _secondary = c)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ColorTile(
                        label: 'Background',
                        color: _background,
                        onTap: () => _pickColor(
                            _background, (c) => setState(() => _background = c)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('Booth Info'),
                _field('Booth Name', _nameCtrl, required: true),
                _field('Welcome Message', _welcomeCtrl,
                    hint: 'Shown to visitors the moment they scan in',
                    maxLines: 2),
                _field('Description', _descCtrl, maxLines: 3),
                _field('Contact Email', _emailCtrl,
                    keyboardType: TextInputType.emailAddress),
                _field('Contact Phone', _phoneCtrl),
                _field('Website', _websiteCtrl),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Booth',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false,
      String? hint,
      int maxLines = 1,
      TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile(
      {required this.label,
      required this.url,
      required this.uploading,
      required this.onTap});
  final String label;
  final String url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBg, width: 1.5),
          image: url.isNotEmpty
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: uploading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : url.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          color: AppColors.textMedium),
                      const SizedBox(height: 4),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMedium)),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('Change $label',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
