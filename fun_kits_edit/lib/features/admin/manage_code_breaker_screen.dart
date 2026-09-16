import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';

/// Exhibitor-scoped — always edits [boothId]'s (the caller's own booth)
/// Code Breaker shared code. Unlike Guess the Number, Code Breaker has no
/// other settings here (enable/points-on-completion still live on its
/// generic Game Settings card) — this screen exists purely so the exhibitor
/// can see or set the one shared 4-digit code every visitor here is
/// currently trying to crack. See CodeBreakerConfig's doc comment for why a
/// shared code is seeded automatically just by opening this screen.
class ManageCodeBreakerScreen extends StatefulWidget {
  const ManageCodeBreakerScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageCodeBreakerScreen> createState() =>
      _ManageCodeBreakerScreenState();
}

class _ManageCodeBreakerScreenState extends State<ManageCodeBreakerScreen> {
  final _fs = FirestoreService();
  late final TextEditingController _customCodeCtrl;
  bool _loading = true;
  bool _revealed = false;
  bool _settingCustom = false;
  String? _customCodeError;
  List<int>? _currentSecret;
  StreamSubscription<CodeBreakerConfig?>? _secretSub;

  @override
  void initState() {
    super.initState();
    _customCodeCtrl = TextEditingController();
    _init();
  }

  Future<void> _init() async {
    // Seeds a random code if this booth's Code Breaker has never had one
    // (e.g. it was toggled on before this feature existed) — a no-op once
    // a doc already exists.
    await _fs.ensureCodeBreakerSeeded(widget.boothId);
    if (!mounted) return;
    setState(() => _loading = false);
    _secretSub = _fs.watchCodeBreakerConfig(widget.boothId).listen((c) {
      if (mounted) setState(() => _currentSecret = c?.currentSecret);
    });
  }

  @override
  void dispose() {
    _customCodeCtrl.dispose();
    _secretSub?.cancel();
    super.dispose();
  }

  Future<void> _randomizeNow() async {
    await _fs.rerollCodeBreakerSecret(widget.boothId);
  }

  Future<void> _setCustomCode() async {
    final raw = _customCodeCtrl.text.trim();
    if (raw.length != 4 || int.tryParse(raw) == null) {
      setState(() => _customCodeError = 'Enter exactly 4 digits.');
      return;
    }
    final digits = raw.split('').map(int.parse).toList();
    if (digits.toSet().length != 4) {
      setState(() => _customCodeError = 'Digits must all be different.');
      return;
    }
    setState(() {
      _settingCustom = true;
      _customCodeError = null;
    });
    await _fs.setCodeBreakerSecret(widget.boothId, digits);
    if (!mounted) return;
    setState(() => _settingCustom = false);
    _customCodeCtrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code updated!')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = palette.textDark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Code Breaker',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Visitors crack a 4-digit code with Bulls & Cows feedback. '
                  'Enable it and set its points on the main Game Settings '
                  'page — this is just the shared code itself.',
                  style: TextStyle(color: palette.textMedium, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 16, color: color),
                          const SizedBox(width: 6),
                          const Text('Current Code',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          const Spacer(),
                          Text(
                            _currentSecret == null || _currentSecret!.isEmpty
                                ? '—'
                                : (_revealed
                                    ? _currentSecret!.join('  ')
                                    : '••••'),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: color,
                                letterSpacing: 2),
                          ),
                          IconButton(
                            icon: Icon(
                                _revealed
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18),
                            tooltip: _revealed ? 'Hide' : 'Reveal',
                            onPressed: () =>
                                setState(() => _revealed = !_revealed),
                          ),
                        ],
                      ),
                      Text(
                        'The one shared code every visitor here is currently '
                        'trying to crack. It automatically changes to a new '
                        'random code whenever someone solves it — or set '
                        'your own below any time.',
                        style:
                            TextStyle(fontSize: 11, color: palette.textMedium),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _currentSecret == null ? null : _randomizeNow,
                          icon: const Icon(Icons.casino_rounded, size: 16),
                          label: const Text('Randomize Now'),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCodeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Set a specific code (4 unique digits)',
                                errorText: _customCodeError,
                                counterText: '',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: _settingCustom
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))
                                : TextButton(
                                    onPressed: _setCustomCode,
                                    child: const Text('Set')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
