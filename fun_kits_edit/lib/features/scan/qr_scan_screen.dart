import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';
import '../booth/booth_screen.dart';

/// Camera-based QR scanner for entering an exhibitor's booth. Each booth's
/// unique code (see ExhibitorQrScreen, where an exhibitor generates/prints
/// their own) encodes `funkits:booth:<exhibitorId>`. A manual code/booth-
/// number field, and picking an existing photo from the gallery, are both
/// offered as fallbacks when the camera isn't available or the code won't
/// scan live.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  static const _prefix = 'funkits:booth:';

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

  Future<void> _handleCode(String raw) async {
    if (_busy) return;
    final code = raw.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    unawaited(_controller.stop());

    final id = code.startsWith(_prefix) ? code.substring(_prefix.length) : code;

    try {
      ExhibitorModel? exhibitor = await _fs.getExhibitorById(id);
      exhibitor ??= await _fs.getExhibitorByBoothNumber(id);

      if (exhibitor == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Booth not found. Check the code and try again.';
          _busy = false;
        });
        unawaited(_controller.start());
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BoothScreen(exhibitor: exhibitor!)),
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = null;
      });
      unawaited(_controller.start());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _busy = false;
      });
      unawaited(_controller.start());
    }
  }

  void _submitManual() => _handleCode(_manualCtrl.text);

  /// Lets a visitor pick an existing photo (e.g. one they took of a booth's
  /// QR earlier, or a screenshot someone sent them) and decodes it with the
  /// same `MobileScannerController` used for live scanning — no separate
  /// decoding library needed. A successful decode is routed through the
  /// exact same `_handleCode()` path as a live camera scan.
  Future<void> _pickFromGallery() async {
    if (_pickingImage || _busy) return;
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    unawaited(_controller.stop());
    try {
      // No imageQuality/compression here on purpose — compressing a QR
      // photo risks making its modules undecodable.
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
            _error = "No QR code found in that image. Try another one.");
        unawaited(_controller.start());
        return;
      }

      setState(() => _pickingImage = false);
      await _handleCode(value); // manages its own busy state + controller
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Booth QR',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.primary,
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
              if (value != null && value.isNotEmpty) _handleCode(value);
            },
          ),
          // Scan frame overlay
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
                      "Point your camera at a booth's QR code, or pick a "
                      "photo from your gallery",
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Or enter booth code / number',
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
                          color: AppColors.primary,
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
