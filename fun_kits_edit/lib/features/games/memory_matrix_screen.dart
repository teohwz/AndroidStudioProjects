import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/firestore_service.dart';
import 'game_common.dart';

/// Fallback deck used when an exhibitor hasn't uploaded any pair images yet
/// — the game still works out of the box, just without their branding.
const List<String> _fallbackEmojis = ['🎮', '⭐', '🎨', '🎯', '🎪', '🎁'];

/// MEMORY CARDS (key: memory_matrix, unchanged for history/leaderboard
/// continuity) — classic flip-two-tiles-find-the-match, using the
/// exhibitor's own uploaded images per pair (see ManageMemoryCardsScreen /
/// MemoryPairsConfig) so every booth's board looks different. Falls back to
/// a generic emoji deck if the exhibitor hasn't set images. Points reward
/// stays the flat "points on completion" value from the Game Settings
/// screen scaled by how efficiently the visitor found every pair — no
/// separate prize pool needed for this game.
class MemoryMatrixScreen extends StatefulWidget {
  const MemoryMatrixScreen({
    super.key,
    this.accentColor = AppColors.primary,
    this.exhibitorId,
    this.title = 'Memory Cards',
  });

  final Color accentColor;
  final String? exhibitorId;
  final String title;

  @override
  State<MemoryMatrixScreen> createState() => _MemoryMatrixScreenState();
}

class _MemoryMatrixScreenState extends State<MemoryMatrixScreen> {
  final _fs = FirestoreService();
  final _rand = Random();

  bool _loadingContent = true;
  List<String> _pairContent = []; // image URLs, or emoji fallback
  bool _usingImages = false;

  List<int> _deck = []; // each entry is a pairIndex, length = 2*pairCount
  List<bool> _flipped = [];
  List<bool> _matched = [];
  final List<int> _selected = [];
  bool _busy = false;
  bool _started = false;
  bool _gameOver = false;
  int _moves = 0;
  DateTime? _startedAt;

  int get _pairCount => _pairContent.length;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (widget.exhibitorId != null && widget.exhibitorId!.isNotEmpty) {
      final config = await _fs.getMemoryPairsConfig(widget.exhibitorId!);
      if (config != null && config.hasContent) {
        if (mounted) {
          setState(() {
            _pairContent = config.pairImageUrls;
            _usingImages = true;
            _loadingContent = false;
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _pairContent = _fallbackEmojis;
        _usingImages = false;
        _loadingContent = false;
      });
    }
  }

  void _start() {
    final deck = <int>[
      for (var i = 0; i < _pairCount; i++) ...[i, i]
    ]..shuffle(_rand);
    setState(() {
      _deck = deck;
      _flipped = List.filled(deck.length, false);
      _matched = List.filled(deck.length, false);
      _selected.clear();
      _busy = false;
      _started = true;
      _gameOver = false;
      _moves = 0;
      _startedAt = DateTime.now();
    });
  }

  void _onTapCard(int i) {
    if (_busy || _matched[i] || _flipped[i] || _selected.length >= 2) return;
    setState(() {
      _flipped[i] = true;
      _selected.add(i);
    });
    if (_selected.length < 2) return;

    _moves += 1;
    final a = _selected[0];
    final b = _selected[1];
    if (_deck[a] == _deck[b]) {
      setState(() {
        _matched[a] = true;
        _matched[b] = true;
        _selected.clear();
      });
      if (_matched.every((m) => m)) {
        _endGame();
      }
    } else {
      setState(() => _busy = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _flipped[a] = false;
          _flipped[b] = false;
          _selected.clear();
          _busy = false;
        });
      });
    }
  }

  Future<void> _endGame() async {
    setState(() {
      _started = false;
      _gameOver = true;
    });
    final base = _pairCount * 20;
    final extraMoves = (_moves - _pairCount).clamp(0, 1000);
    final score = (base - extraMoves * 4).clamp((_pairCount * 5), base);
    final durationMs = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final allowed = await submitGameScore('memory_matrix', score,
        exhibitorId: widget.exhibitorId, durationMs: durationMs);
    if (!mounted) return;
    if (!allowed) {
      showPlayLimitDialog(context, color: widget.accentColor);
      return;
    }
    showGameResultDialog(
      context,
      emoji: _moves <= _pairCount + 2 ? '🏆' : '🃏',
      title: 'All Matched!',
      message: 'You found all $_pairCount pairs in $_moves moves — $score points.',
      color: widget.accentColor,
      onPlayAgain: _start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: gameAppBar(widget.title, color),
      body: _loadingContent
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StatusRow(
                    moves: _moves,
                    status: !_started && !_gameOver
                        ? 'Ready?'
                        : _busy
                            ? 'Not a match...'
                            : 'Find the pairs!',
                    color: color,
                  ),
                  const SizedBox(height: 24),
                  if (!_started && !_gameOver)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🃏', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 12),
                            Text(
                                'Flip two cards at a time and find all '
                                '$_pairCount matching pairs.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMedium)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _start,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              child: const Text('Start',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _deck.length,
                        itemBuilder: (context, i) {
                          final revealed = _flipped[i] || _matched[i];
                          return GestureDetector(
                            onTap: () => _onTapCard(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: _matched[i]
                                    ? AppColors.success.withOpacity(0.18)
                                    : revealed
                                        ? Colors.white
                                        : color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _matched[i]
                                        ? AppColors.success
                                        : color.withOpacity(0.3)),
                              ),
                              alignment: Alignment.center,
                              child: revealed
                                  ? (_usingImages
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                              imageUrl: _pairContent[_deck[i]],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity),
                                        )
                                      : Text(_pairContent[_deck[i]],
                                          style: const TextStyle(fontSize: 26)))
                                  : Icon(Icons.help_outline_rounded,
                                      color: Colors.white.withOpacity(0.85), size: 22),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.moves, required this.status, required this.color});
  final int moves;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Moves: $moves',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ),
        Text(status,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textMedium)),
      ],
    );
  }
}
