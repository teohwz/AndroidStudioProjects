import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Exhibitor-scoped camera scanner for verifying a visitor's physical-prize
/// redemption code and marking it collected — see
/// FirestoreService.redeemPrizeCode. Reached from the "Scan to Redeem"
/// button on ExhibitorPrizeWinsScreen. Mirrors QrScanScreen's booth
/// check-in pattern exactly: live camera scan, a manual code-entry field
/// as fallback, and picking an existing photo from the gallery.
class ScanRedeemScreen extends StatefulWidget {
  const ScanRedeemScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ScanRedeemScreen> createState() => _ScanRedeemScreenState();
}

class _ScanRedeemScreenState extends State<ScanRedeemScreen> {
  static const _prefix = 'funkits:prize:';

  final _fs = FirestoreService();
  final _controller = MobileScannerController();
  final _manualCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _busy = false;
  bool _pickingImage = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  /// A scanned QR encodes `funkits:prize:<winId>:<code>` — parsed here and
  /// routed through the same [_redeem] path a manually-typed code takes.
  Future<void> _handleQrCode(String raw) async {
    if (_busy) return;
    final value = raw.trim();
    if (value.isEmpty) return;
    if (!value.startsWith(_prefix)) {
      setState(() => _error = "That doesn't look like a prize code.");
      return;
    }
    final rest = value.substring(_prefix.length);
    final parts = rest.split(':');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      setState(() => _error = "That doesn't look like a prize code.");
      return;
    }
    await _redeem(winId: parts[0], code: parts[1]);
  }

  Future<void> _submitManual() async {
    final code = _manualCtrl.text.trim();
    if (code.isEmpty) return;
    await _redeem(code: code);
  }

  Future<void> _redeem({String? winId, required String code}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    unawaited(_controller.stop());

    try {
      final result = await _fs.redeemPrizeCode(
        boothId: widget.boothId,
        code: code,
        winId: winId,
      );
      if (!mounted) return;

      if (result.success) {
        _manualCtrl.clear();
        final win = result.win!;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 48,
                    color: Theme.of(ctx).extension<AppPalette>()!.success),
                const SizedBox(height: 12),
                const Text('Verified!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 6),
                Text('${win.userName} — ${win.prizeLabel}\nMarked as collected.',
                    textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        );
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = null;
        });
        unawaited(_controller.start());
      } else {
        setState(() {
          _busy = false;
          _error = _messageFor(result.failureReason);
        });
        unawaited(_controller.start());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
      unawaited(_controller.start());
    }
  }

  String _messageFor(String? reason) {
    switch (reason) {
      case 'not_found':
        return 'No prize found with that code at this booth.';
      case 'wrong_booth':
        return 'That code belongs to a different booth.';
      case 'points_prize':
        return "That win doesn't have a physical prize to redeem.";
      case 'invalid_code':
        return "That code doesn't match. Double-check and try again.";
      case 'already_collected':
        return 'This prize has already been collected.';
      default:
        return 'Could not verify that code.';
    }
  }

  /// Lets staff pick an existing photo (e.g. a screenshot the visitor sent)
  /// and decodes it with the same `MobileScannerController` used for live
  /// scanning — same pattern as QrScanScreen's gallery fallback.
  Future<void> _pickFromGallery() async {
    if (_pickingImage || _busy) return;
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    unawaited(_controller.stop());
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        unawaited(_controller.start());
        return;
      }

      final capture = await _controller.analyzeImage(picked.path);
      final barcodes = capture?.barcodes ?? const [];
      final value = barcodes.isNotEmpty ? barcodes.first.rawValue : null;

      if (value == null || value.isEmpty) {
        if (!mounted) return;
        setState(() =>
            _error = 'No QR code found in that image. Try another one.');
        unawaited(_controller.start());
        return;
      }

      setState(() => _pickingImage = false);
      await _handleQrCode(value); // manages its own busy state + controller
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read a QR code from that image.');
      unawaited(_controller.start());
    } finally {
      if (mounted && _pickingImage) setState(() => _pickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan to Redeem',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded),
            tooltip: 'Scan from gallery',
            onPressed: (_busy || _pickingImage) ? null : _pickFromGallery,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final value = barcodes.first.rawValue;
              if (value != null && value.isNotEmpty) _handleQrCode(value);
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_busy || _pickingImage)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Scan a visitor's prize QR, or pick a photo from your "
                      "gallery",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Or enter the 6-digit code',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white),
                          onPressed: _busy ? null : _submitManual,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
