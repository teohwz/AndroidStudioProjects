import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/game_content_model.dart';
import '../../core/services/firestore_service.dart';
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
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: '1');
    _maxCtrl = TextEditingController(text: '100');
    _pointsCtrl = TextEditingController(text: '50');
    _hintCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _pointsCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guess the Number saved! 🔢')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Guess the Number 🔢',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.guessNumberColor,
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
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
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
                  gradient: const LinearGradient(colors: [
                    AppColors.guessNumberColor,
                    Color(0xFF8E99E8),
                  ]),
                ),
              ),
            ),
    );
  }
}
