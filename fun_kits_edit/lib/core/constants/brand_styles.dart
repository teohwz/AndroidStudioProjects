import 'package:flutter/material.dart';

// ─── BRAND PLACEHOLDER STYLES ───────────────────────────────────────────────
// Used to render a brand's logo tile when no real image has been uploaded
// yet (RewardModel.brandImageUrl == ''). Purely a demo/prototype visual —
// deliberately NOT a real logo (no trademarked artwork is bundled with this
// app). A Super Admin can replace this with a real, licensed logo at any
// time via the reward edit form; nothing else needs to change when they do.
class BrandStyle {
  final Color color;
  final String emoji;
  const BrandStyle(this.color, this.emoji);
}

const Map<String, BrandStyle> kBrandStyles = {
  'Grab': BrandStyle(Color(0xFF00B14F), '🚗'),
  'foodpanda': BrandStyle(Color(0xFFD70F64), '🐼'),
  "Touch 'n Go eWallet": BrandStyle(Color(0xFF00A8E1), '💳'),
  'Shopee': BrandStyle(Color(0xFFEE4D2D), '🛒'),
  'Lazada': BrandStyle(Color(0xFF0F136D), '📦'),
  'Watsons': BrandStyle(Color(0xFF00A9E0), '💊'),
  'AEON': BrandStyle(Color(0xFFE60027), '🏬'),
  "Lotus's": BrandStyle(Color(0xFF00A651), '🛍️'),
  'Tealive': BrandStyle(Color(0xFF6B2E5F), '🧋'),
  'ZUS Coffee': BrandStyle(Color(0xFF1B1B1B), '☕'),
};

/// Deterministic fallback for a brand name not in the curated list above —
/// still consistent (same brand always gets the same color) without needing
/// every possible future brand hardcoded here.
BrandStyle brandStyleFor(String brandName) {
  final known = kBrandStyles[brandName];
  if (known != null) return known;
  final palette = [
    const Color(0xFF6C63FF),
    const Color(0xFFFF6584),
    const Color(0xFF43D787),
    const Color(0xFFFF9F43),
    const Color(0xFF4ECDC4),
  ];
  final idx = brandName.isEmpty ? 0 : brandName.codeUnitAt(0) % palette.length;
  final initial = brandName.isNotEmpty ? brandName[0].toUpperCase() : '?';
  return BrandStyle(palette[idx], initial);
}
