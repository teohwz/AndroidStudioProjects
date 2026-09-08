// ─── GAME TYPE REGISTRY ─────────────────────────────────────────────────────
// Single source of truth for every `gameType` string written to
// `leaderboard/{uid}.gameBreakdown` and `game_sessions.gameType`. Used to
// populate the Leaderboard's "Per-Game" filter dropdown. If a new game is
// added, add its key here too so it shows up as a filter option.
class GameTypeDef {
  final String key;
  final String label;
  final String emoji;
  const GameTypeDef(this.key, this.label, this.emoji);
}

const List<GameTypeDef> kGameTypes = [
  GameTypeDef('quiz', 'Quiz', '🧠'),
  GameTypeDef('puzzle', 'Slide Puzzle', '🧩'),
  GameTypeDef('lucky_draw', 'Lucky Draw', '🎰'),
  GameTypeDef('reflex_tap', 'Reflex Tap', '⚡'),
  GameTypeDef('memory_matrix', 'Memory Matrix', '🧩'),
  GameTypeDef('code_breaker', 'Code Breaker', '🔐'),
  GameTypeDef('rgb_master', 'RGB Master', '🎨'),
  GameTypeDef('speed_typing', 'Speed Typing', '⌨️'),
];

// ─── PER-BOOTH GENERIC GAMES ────────────────────────────────────────────────
// The 6 booth-agnostic games each exhibitor can independently enable/disable
// and set a flat completion point-value for at their own booth (Quiz and
// Lucky Draw are exhibitor-AUTHORED content instead — creating one already
// means "enabled", and their point values are set per-quiz/per-draw, not
// here). Each visitor gets exactly 1 free play per game per booth, plus one
// shared bonus attempt per booth (spendable on any one of these games) once
// they check in — see FirestoreService.canPlayGame/recordGamePlay.
const List<GameTypeDef> kGenericBoothGames = [
  GameTypeDef('reflex_tap', 'Reflex Tap', '⚡'),
  GameTypeDef('memory_matrix', 'Memory Matrix', '🧩'),
  GameTypeDef('code_breaker', 'Code Breaker', '🔐'),
  GameTypeDef('rgb_master', 'RGB Master', '🎨'),
  GameTypeDef('speed_typing', 'Speed Typing', '⌨️'),
  GameTypeDef('puzzle', 'Slide Puzzle', '🧩'),
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
