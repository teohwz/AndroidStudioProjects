import 'package:flutter/material.dart';

// ─── POINTS SHOP CATALOG ────────────────────────────────────────────────────
// Deliberately virtual-only: profile cosmetics redeemed with points earned
// from games/booths. No physical prizes are listed or promised here — Lucky
// Draw remains the only path to a real-world prize. Kept as a static list
// (not Firestore-managed) since the prototype doesn't need organizers to
// edit the catalog live.
enum ShopItemKind { frame, badge }

class ShopItem {
  final String id;
  final String name;
  final String emoji;
  final int cost;
  final ShopItemKind kind;
  final Color color;
  const ShopItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.kind,
    required this.color,
  });
}

const List<ShopItem> kShopCatalog = [
  // Avatar frames — colored ring shown around the profile avatar.
  ShopItem(
    id: 'frame_gold',
    name: 'Gold Ring',
    emoji: '🟡',
    cost: 150,
    kind: ShopItemKind.frame,
    color: Color(0xFFFFD700),
  ),
  ShopItem(
    id: 'frame_neon',
    name: 'Neon Ring',
    emoji: '🟢',
    cost: 150,
    kind: ShopItemKind.frame,
    color: Color(0xFF43D787),
  ),
  ShopItem(
    id: 'frame_royal',
    name: 'Royal Ring',
    emoji: '🟣',
    cost: 250,
    kind: ShopItemKind.frame,
    color: Color(0xFF6C63FF),
  ),
  ShopItem(
    id: 'frame_fire',
    name: 'Fire Ring',
    emoji: '🔴',
    cost: 250,
    kind: ShopItemKind.frame,
    color: Color(0xFFFF6B6B),
  ),
  // Name badges — small emoji chip shown next to the display name.
  ShopItem(
    id: 'badge_star',
    name: 'Star Badge',
    emoji: '⭐',
    cost: 80,
    kind: ShopItemKind.badge,
    color: Color(0xFFFFD700),
  ),
  ShopItem(
    id: 'badge_crown',
    name: 'Crown Badge',
    emoji: '👑',
    cost: 300,
    kind: ShopItemKind.badge,
    color: Color(0xFFFFD700),
  ),
  ShopItem(
    id: 'badge_rocket',
    name: 'Rocket Badge',
    emoji: '🚀',
    cost: 120,
    kind: ShopItemKind.badge,
    color: Color(0xFF4ECDC4),
  ),
  ShopItem(
    id: 'badge_heart',
    name: 'Heart Badge',
    emoji: '💖',
    cost: 100,
    kind: ShopItemKind.badge,
    color: Color(0xFFFF6584),
  ),
];
