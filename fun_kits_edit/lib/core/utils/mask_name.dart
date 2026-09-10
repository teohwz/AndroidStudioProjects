// ─── WINNER NAME MASKING ────────────────────────────────────────────────────
// Used anywhere a winner's name is shown publicly (Lucky Draw's winner
// banner, the Spin Wheel/Scratch Card "Recent Winners" list) — never the
// exhibitor-facing Prize Wins hand-out checklist, which needs the real name
// to identify who to hand a physical prize to in person.

/// Masks [name] to its first character (uppercased) followed by exactly
/// three asterisks, e.g. a name starting with "L" always shows as "L***" —
/// regardless of the real name's length. Falls back to "A***" for an empty
/// or missing name so the UI never shows a blank winner.
String maskWinnerName(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'A***';
  return '${trimmed[0].toUpperCase()}***';
}
