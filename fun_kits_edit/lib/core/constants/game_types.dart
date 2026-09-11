import 'package:flutter/material.dart';

// ─── GAME TYPE REGISTRY ─────────────────────────────────────────────────────
// Single source of truth for every `gameType` string written to
// `leaderboard/{uid}.gameBreakdown` and `game_sessions.gameType`. Used to
// populate the Leaderboard's "Per-Game" filter dropdown. If a new game is
// added, add its key here too so it shows up as a filter option.
//
// `emoji` is kept (not removed) so any screen not yet migrated to the new
// icon-badge design keeps compiling and rendering exactly as before; `icon`
// is the new Material Icons equivalent used by redesigned screens — see
// the UI redesign's Phase 2 (visitor screens).
class GameTypeDef {
  final String key;
  final String label;
  final String emoji;
  final IconData icon;
  const GameTypeDef(this.key, this.label, this.emoji, this.icon);
}

const List<GameTypeDef> kGameTypes = [
  GameTypeDef('quiz', 'Quiz', '🧠', Icons.quiz_rounded),
  GameTypeDef('puzzle', 'Slide Puzzle', '🧩', Icons.extension_rounded),
  GameTypeDef('lucky_draw', 'Lucky Draw', '🎰', Icons.confirmation_number_rounded),
  GameTypeDef('reflex_tap', 'Reflex Tap', '⚡', Icons.bolt_rounded),
  GameTypeDef('memory_matrix', 'Memory Matrix', '🃏', Icons.style_rounded),
  GameTypeDef('code_breaker', 'Code Breaker', '🔐', Icons.lock_rounded),
  GameTypeDef('rgb_master', 'RGB Master', '🎨', Icons.palette_rounded),
  GameTypeDef('speed_typing', 'Speed Typing', '⌨️', Icons.keyboard_rounded),
  GameTypeDef('spin_wheel', 'Spin Wheel', '🎡', Icons.autorenew_rounded),
  GameTypeDef('scratch_card', 'Scratch Card', '🪙', Icons.layers_rounded),
  GameTypeDef('guess_number', 'Guess the Number', '🔢', Icons.pin_rounded),
];

// ─── PER-BOOTH GENERIC GAMES ────────────────────────────────────────────────
// The 6 booth-agnostic games each exhibitor can independently enable/disable
// and set a flat completion point-value for at their own booth (Quiz and
// Lucky Draw are exhibitor-AUTHORED content instead — creating one already
// means "enabled", and their point values are set per-quiz/per-draw, not
// here). Every visitor shares ONE attempt pool per booth (1 baseline + up
// to 3 more earned via check-in / Follow-the-Exhibitor / Play-a-Mini-Game
// booth tasks — max 4), spendable on any of that booth's games (these 6
// plus the 3 prize games below) — see FirestoreService.recordGamePlay and
// BoothAttemptPool.
const List<GameTypeDef> kGenericBoothGames = [
  GameTypeDef('reflex_tap', 'Reflex Tap', '⚡', Icons.bolt_rounded),
  GameTypeDef('memory_matrix', 'Memory Matrix', '🧩', Icons.style_rounded),
  GameTypeDef('code_breaker', 'Code Breaker', '🔐', Icons.lock_rounded),
  GameTypeDef('rgb_master', 'RGB Master', '🎨', Icons.palette_rounded),
  GameTypeDef('speed_typing', 'Speed Typing', '⌨️', Icons.keyboard_rounded),
  GameTypeDef('puzzle', 'Slide Puzzle', '🧩', Icons.extension_rounded),
];

/// Default flat points a generic booth game awards on completion until the
/// exhibitor customizes it.
const Map<String, int> kDefaultGamePoints = {
  'reflex_tap': 20,
  'memory_matrix': 20,
  'code_breaker': 25,
  'rgb_master': 20,
  'speed_typing': 20,
  'puzzle': 15,
};

// ─── PER-BOOTH PRIZE GAMES ──────────────────────────────────────────────────
// Games with a dedicated exhibitor-authored content editor (a Firestore
// `game_content/{boothId}_{gameType}` doc) rather than the simple flat
// enable/points toggle above. A game only shows up on the visitor's booth
// screen once the exhibitor has configured content for it — see
// FirestoreService.getGameContent and the booth screen's conditional tiles.
const List<GameTypeDef> kPrizeBoothGames = [
  GameTypeDef('spin_wheel', 'Spin Wheel', '🎡', Icons.autorenew_rounded),
  GameTypeDef('scratch_card', 'Scratch Card', '🪙', Icons.layers_rounded),
  GameTypeDef('guess_number', 'Guess the Number', '🔢', Icons.pin_rounded),
];
