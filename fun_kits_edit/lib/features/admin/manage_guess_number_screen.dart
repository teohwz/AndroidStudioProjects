import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../../shared/widgets/fun_button.dart';

/// Exhibitor-scoped — always edits [boothId]'s (the caller's own booth)
/// Guess the Number range, reward, and optional hint. Visitors get
/// automatic Higher/Lower feedback on every guess, capped at
/// [GuessNumberConfig.maxAttempts] attempts, plus this hint revealable
/// any time they're stuck.
class ManageGuessNumberScreen extends StatefulWidget {
  const ManageGuessNumberScreen({super.key, required this.boothId});

  final String boothId;

  @override
  State<ManageGuessNumberScreen> createState() =>
      _ManageGuessNumberScreenState();
}

class _ManageGuessNumberScreenState extends State<ManageGuessNumberScreen> {
  final _fs = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _pointsCtrl;
  late final TextEditingController _hintCtrl;
  late final TextEditingController _customSecretCtrl;
  bool _loading = true;
  bool _saving = false;
  bool _secretRevealed = false;
  bool _settingCustom = false;
  String? _customSecretError;
  // Kept in sync live (not just from the one-shot _load()) so a quick
  // Randomize/Set-custom action is never clobbered by a later main Save
  // that would otherwise submit a stale currentSecret.
  int? _currentSecret;
  StreamSubscription<GuessNumberConfig?>? _secretSub;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: '1');
    _maxCtrl = TextEditingController(text: '100');
    _pointsCtrl = TextEditingController(text: '50');
    _hintCtrl = TextEditingController();
    _customSecretCtrl = TextEditingController();
    _load();
    _secretSub = _fs.watchGuessNumberConfig(widget.boothId).listen((c) {
      if (mounted) setState(() => _currentSecret = c?.currentSecret);
    });
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _pointsCtrl.dispose();
    _hintCtrl.dispose();
    _customSecretCtrl.dispose();
    _secretSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    // Guarantees a `guess_number` doc exists before this screen ever shows
    // its controls — see ensureGuessNumberSeeded's doc comment for why:
    // without it, "Randomize Now"/"Set" would fail (NOT_FOUND) on a booth
    // that had never yet tapped "Save Guess the Number" once, leaving the
    // "Set" button stuck spinning forever. Mirrors ManageCodeBreakerScreen.
    await _fs.ensureGuessNumberSeeded(widget.boothId);
    final config = await _fs.getGuessNumberConfig(widget.boothId);
    if (!mounted) return;
    if (config != null) {
      _minCtrl.text = '${config.minValue}';
      _maxCtrl.text = '${config.maxValue}';
      _pointsCtrl.text = '${config.rewardPoints}';
      _hintCtrl.text = config.hint;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final min = int.parse(_minCtrl.text.trim());
    final max = int.parse(_maxCtrl.text.trim());
    if (max <= min) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Max must be greater than min.')));
      return;
    }
    setState(() => _saving = true);
    await _fs.saveGuessNumberConfig(
      GuessNumberConfig(
        boothId: widget.boothId,
        minValue: min,
        maxValue: max,
        rewardPoints: int.tryParse(_pointsCtrl.text.trim())?.clamp(1, 100000) ?? 50,
        hint: _hintCtrl.text.trim(),
        // Preserve whatever the current shared answer already is (kept live
        // via _secretSub) — saveGuessNumberConfig only rolls a new one if
        // this is null or no longer fits the (possibly just-edited) range.
        currentSecret: _currentSecret,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Guess the Number saved!'),
        ],
      ),
    ));
  }

  Future<void> _randomizeNow() async {
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    if (min == null || max == null || max <= min) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Save a valid min/max range first.')));
      return;
    }
    try {
      await _fs.rerollGuessNumberSecret(widget.boothId, min, max);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not randomize the answer: $e')));
    }
  }

  Future<void> _setCustomSecret() async {
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    final value = int.tryParse(_customSecretCtrl.text.trim());
    if (min == null || max == null || max <= min) {
      setState(() => _customSecretError = 'Save a valid min/max range first.');
      return;
    }
    if (value == null || value < min || value > max) {
      setState(() => _customSecretError = 'Enter a number between $min and $max.');
      return;
    }
    setState(() {
      _settingCustom = true;
      _customSecretError = null;
    });
    // Always clears _settingCustom, success or failure — previously an
    // uncaught error here (e.g. NOT_FOUND on a booth with no doc yet, see
    // ensureGuessNumberSeeded) left this button spinning forever with no
    // feedback at all, since nothing after a thrown await ever ran.
    try {
      await _fs.setGuessNumberSecret(widget.boothId, value);
      if (!mounted) return;
      _customSecretCtrl.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Answer updated!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _customSecretError = 'Could not set the answer: $e');
    } finally {
      if (mounted) setState(() => _settingCustom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Guess the Number',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: palette.guessNumberColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  Text(
                    'Visitors get up to ${GuessNumberConfig.maxAttempts} '
                    'guesses, with automatic Higher/Lower feedback after '
                    'each one and your hint revealable any time.',
                    style: TextStyle(color: palette.textMedium, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.guessNumberColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: palette.guessNumberColor.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.key_rounded,
                                size: 16, color: palette.guessNumberColor),
                            const SizedBox(width: 6),
                            const Text('Current Answer',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            const Spacer(),
                            Text(
                              _currentSecret == null
                                  ? '—'
                                  : (_secretRevealed ? '$_currentSecret' : '••'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: palette.guessNumberColor),
                            ),
                            IconButton(
                              icon: Icon(
                                  _secretRevealed
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 18),
                              tooltip: _secretRevealed ? 'Hide' : 'Reveal',
                              onPressed: () => setState(
                                  () => _secretRevealed = !_secretRevealed),
                            ),
                          ],
                        ),
                        Text(
                          'The one shared answer every visitor here is '
                          'currently guessing. It automatically changes to a '
                          'new random number whenever someone solves it — or '
                          'set your own below any time.',
                          style: TextStyle(
                              fontSize: 11, color: palette.textMedium),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                _currentSecret == null ? null : _randomizeNow,
                            icon: const Icon(Icons.casino_rounded, size: 16),
                            label: const Text('Randomize Now'),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customSecretCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Set a specific answer',
                                  errorText: _customSecretError,
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
                                      onPressed: _setCustomSecret,
                                      child: const Text('Set')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Min', border: OutlineInputBorder()),
                          validator: (v) =>
                              int.tryParse((v ?? '').trim()) == null
                                  ? 'Number'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Max', border: OutlineInputBorder()),
                          validator: (v) =>
                              int.tryParse((v ?? '').trim()) == null
                                  ? 'Number'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reward points for a correct guess',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        int.tryParse((v ?? '').trim()) == null ? 'Number' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hintCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Hint (optional)',
                      hintText: 'e.g. It\'s a multiple of 5!',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FunButton(
                  label: 'Save Guess the Number',
                  isLoading: _saving,
                  onPressed: _save,
                  gradient: LinearGradient(colors: [
                    palette.guessNumberColor,
                    const Color(0xFF8E99E8),
                  ]),
                ),
              ),
            ),
    );
  }
}
