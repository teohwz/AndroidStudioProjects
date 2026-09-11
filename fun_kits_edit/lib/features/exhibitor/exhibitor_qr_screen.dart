import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Curated look-and-feel presets for an exhibitor's booth QR code. Every
/// preset encodes the exact same `funkits:booth:<boothId>` payload that
/// QrScanScreen already parses — only the drawing changes, never the data —
/// and every color/logo a preset uses comes from the booth's own existing
/// theme (ExhibitorModel), never a freeform picker. This keeps the code
/// reliably scannable: no risk of an exhibitor picking low-contrast colors
/// or an oversized logo that breaks the quiet zone / error correction.
enum QrPreset { plain, rounded, logoBadge }

extension QrPresetX on QrPreset {
  String get storageKey => switch (this) {
        QrPreset.plain => 'plain',
        QrPreset.rounded => 'rounded',
        QrPreset.logoBadge => 'logoBadge',
      };

  String get label => switch (this) {
        QrPreset.plain => 'Plain',
        QrPreset.rounded => 'Rounded',
        QrPreset.logoBadge => 'Logo Badge',
      };

  static QrPreset fromStorageKey(String key) => QrPreset.values.firstWhere(
        (p) => p.storageKey == key,
        orElse: () => QrPreset.plain,
      );
}

/// Lets an exhibitor view, restyle (within the safe presets above), save to
/// their device's gallery, and share/print their own booth's QR code.
/// Reached from the "My QR Code" card on ExhibitorDashboardScreen. Save and
/// share/print are deliberately separate actions: saving uses the `gal`
/// package's native gallery APIs (guaranteed to work on both platforms),
/// while share/print uses the OS share sheet (`share_plus`) — the share
/// sheet has no reliable "save to gallery" destination on Android, so it's
/// kept for sending/printing only.
class ExhibitorQrScreen extends StatefulWidget {
  const ExhibitorQrScreen({super.key, required this.boothId});
  final String boothId;

  @override
  State<ExhibitorQrScreen> createState() => _ExhibitorQrScreenState();
}

class _ExhibitorQrScreenState extends State<ExhibitorQrScreen> {
  final _fs = FirestoreService();
  final _captureKey = GlobalKey();
  bool _savingPreset = false;
  bool _exporting = false;
  bool _savingToGallery = false;

  Future<void> _selectPreset(ExhibitorModel booth, QrPreset preset) async {
    if (_savingPreset || booth.qrPresetStyle == preset.storageKey) return;
    setState(() => _savingPreset = true);
    try {
      await _fs.updateBoothCustomization(
          booth.copyWith(qrPresetStyle: preset.storageKey));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save style — please try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingPreset = false);
    }
  }

  /// Renders the on-screen QR card (via its RepaintBoundary) to PNG bytes.
  /// Shared by both the gallery-save and share/print actions so there's
  /// exactly one place that knows how to capture the card.
  Future<Uint8List?> _captureImageBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Saves the QR image directly into the device's photo gallery via the
  /// `gal` package's native gallery APIs. Deliberately separate from
  /// _shareQr()'s OS share sheet below — the share sheet has no guaranteed
  /// "save to gallery" destination on Android, so a real save needs this
  /// dedicated path instead.
  Future<void> _saveToGallery(ExhibitorModel booth) async {
    if (_savingToGallery) return;
    setState(() => _savingToGallery = true);
    try {
      final bytes = await _captureImageBytes();
      if (bytes == null) return;
      await Gal.putImageBytes(bytes, album: 'Fun Kits');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Saved to your gallery'),
          ],
        ),
      ));
    } on GalException catch (e) {
      if (!mounted) return;
      final msg = e.type == GalExceptionType.accessDenied
          ? 'Photo access denied. Enable it in your device Settings and try again.'
          : 'Could not save the QR code. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save the QR code — please try again.')));
    } finally {
      if (mounted) setState(() => _savingToGallery = false);
    }
  }

  /// Hands the QR image to the OS share sheet — for sending it to someone
  /// or printing it, not for saving to the gallery (see _saveToGallery).
  Future<void> _shareQr(ExhibitorModel booth) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureImageBytes();
      if (bytes == null) return;

      final dir = await Directory.systemTemp.createTemp('booth_qr');
      final safeName =
          (booth.boothNumber.isNotEmpty ? booth.boothNumber : booth.id)
              .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/booth_qr_$safeName.png');
      await file.writeAsBytes(bytes);

      final boothLabel = booth.name.isNotEmpty ? booth.name : 'our booth';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code to visit $boothLabel at Fun Kits!',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not share the QR code — please try again.')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My QR Code',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.exhibitorColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ExhibitorModel?>(
        stream: _fs.watchExhibitor(widget.boothId),
        builder: (context, snap) {
          final booth = snap.data;
          if (booth == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final preset = QrPresetX.fromStorageKey(booth.qrPresetStyle);
          final availablePresets = QrPreset.values
              .where((p) => p != QrPreset.logoBadge || booth.hasLogo)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Visitors scan this at your booth to load your theme, '
                'logo, and games instantly.',
                style: TextStyle(color: palette.textMedium),
              ),
              const SizedBox(height: 20),
              Center(
                child: RepaintBoundary(
                  key: _captureKey,
                  child: _QrCard(booth: booth, preset: preset),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Style',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availablePresets
                    .map((p) => ChoiceChip(
                          label: Text(p.label),
                          selected: preset == p,
                          onSelected: (_) => _selectPreset(booth, p),
                          selectedColor:
                              palette.exhibitorColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: preset == p
                                ? palette.exhibitorColor
                                : palette.textMedium,
                          ),
                        ))
                    .toList(),
              ),
              if (!booth.hasLogo)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Add a logo in Customize Booth to unlock the Logo Badge '
                    'style.',
                    style: TextStyle(color: palette.textMedium, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _savingToGallery ? null : () => _saveToGallery(booth),
                  icon: _savingToGallery
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('Save to Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.exhibitorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _shareQr(booth),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: const Text('Share / Print'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.exhibitorColor,
                    side: BorderSide(color: palette.exhibitorColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.booth, required this.preset});
  final ExhibitorModel booth;
  final QrPreset preset;

  @override
  Widget build(BuildContext context) {
    final payload = 'funkits:booth:${booth.id}';
    const qrSize = 220.0;

    Widget qr;
    switch (preset) {
      case QrPreset.plain:
        qr = QrImageView(
          data: payload,
          size: qrSize,
          backgroundColor: booth.backgroundColor,
          eyeStyle:
              QrEyeStyle(eyeShape: QrEyeShape.square, color: booth.themeColor),
          dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: booth.themeColor),
        );
        break;
      case QrPreset.rounded:
        qr = QrImageView(
          data: payload,
          size: qrSize,
          backgroundColor: booth.backgroundColor,
          eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.circle, color: booth.secondaryColor),
          dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: booth.themeColor),
        );
        break;
      case QrPreset.logoBadge:
        qr = QrImageView(
          data: payload,
          size: qrSize,
          backgroundColor: booth.backgroundColor,
          eyeStyle:
              QrEyeStyle(eyeShape: QrEyeShape.square, color: booth.themeColor),
          dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: booth.themeColor),
          // Higher error correction leaves the code reliably scannable even
          // with the logo covering its center.
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          embeddedImage: booth.hasLogo
              ? CachedNetworkImageProvider(booth.logoUrl)
              : null,
          embeddedImageStyle: const QrEmbeddedImageStyle(
            size: Size(44, 44),
          ),
        );
        break;
    }

    // This card's own background stays fixed white regardless of app theme —
    // it's a mockup of the physical printed card an exhibitor would put on
    // their table, not app chrome, so it shouldn't go dark in dark mode.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (booth.hasLogo && preset != QrPreset.logoBadge) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: booth.logoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          qr,
          const SizedBox(height: 14),
          Text(
            booth.name.isNotEmpty
                ? booth.name
                : 'Booth ${booth.boothNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: booth.themeColor),
          ),
          if (booth.boothNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Booth #${booth.boothNumber}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
