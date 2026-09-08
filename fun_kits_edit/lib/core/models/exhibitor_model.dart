import 'package:flutter/material.dart';

import '../constants/game_types.dart';

/// Per-game customization an exhibitor sets for their own booth: whether a
/// generic game (see kGenericBoothGames) is offered there at all, and how
/// many points it awards on completion. Quiz/Lucky Draw aren't in here —
/// they're exhibitor-authored content instead (see QuizModel/LuckyDrawModel).
class BoothGameConfig {
  final bool enabled;
  final int points;

  const BoothGameConfig({this.enabled = true, this.points = 0});

  factory BoothGameConfig.fromMap(Map<String, dynamic>? map, String gameType) {
    if (map == null) {
      return BoothGameConfig(
          enabled: true, points: kDefaultGamePoints[gameType] ?? 10);
    }
    return BoothGameConfig(
      enabled: map['enabled'] ?? true,
      points: (map['points'] as num?)?.toInt() ??
          kDefaultGamePoints[gameType] ??
          10,
    );
  }

  Map<String, dynamic> toMap() => {'enabled': enabled, 'points': points};
}

class ExhibitorModel {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final String contactEmail;
  final String contactPhone;
  final String website;
  /// Social links used by the visitor-facing "Follow the Exhibitor" booth
  /// task (see booth_screen.dart) — up to 3 sub-tasks (Facebook, Instagram,
  /// Website), each shown only when its own field here is non-empty.
  final String facebookUrl;
  final String instagramUrl;
  final String themeColorHex; // primary color
  final String boothNumber;
  final String category;
  final List<String> tags;
  final bool isSponsored;
  final DateTime? createdAt;

  // ── Exhibitor ownership + booth customization (added for the per-booth
  // exhibitor account system) ────────────────────────────────────────────
  /// Null until a Super-Admin-issued invite code is redeemed against this
  /// booth — see FirestoreService.redeemExhibitorInvite. Once set, only
  /// this uid (or a Super Admin) may ever edit this booth going forward.
  final String? ownerUid;
  final String bannerImageUrl;
  final String secondaryColorHex;
  final String backgroundColorHex;
  final String welcomeMessage;
  /// Super Admin can deactivate a booth (e.g. exhibitor left early) without
  /// deleting its data. An inactive booth's QR/listing stops working for
  /// visitors but the exhibitor's own data is preserved.
  final bool isActive;
  /// Keyed by a kGenericBoothGames game-type key.
  final Map<String, BoothGameConfig> gameConfig;
  /// Which curated QR-code preset (see ExhibitorQrScreen) the exhibitor has
  /// chosen for their booth's printable/shareable QR code. Purely cosmetic —
  /// every preset still encodes the same `funkits:booth:<id>` payload that
  /// QrScanScreen parses, so this never affects scanning. One of 'plain',
  /// 'rounded', 'logoBadge'; unrecognized/missing values fall back to plain.
  final String qrPresetStyle;

  ExhibitorModel({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl = '',
    required this.contactEmail,
    this.contactPhone = '',
    this.website = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.themeColorHex = '#6C63FF',
    this.boothNumber = '',
    this.category = 'General',
    this.tags = const [],
    this.isSponsored = false,
    this.createdAt,
    this.ownerUid,
    this.bannerImageUrl = '',
    this.secondaryColorHex = '#FF6584',
    this.backgroundColorHex = '#F8F7FF',
    this.welcomeMessage = '',
    this.isActive = true,
    this.gameConfig = const {},
    this.qrPresetStyle = 'plain',
  });

  /// Parse hex string to Flutter Color
  Color get themeColor => Color(
      int.parse(themeColorHex.replaceFirst('#', '0xFF')));
  Color get secondaryColor => Color(
      int.parse(secondaryColorHex.replaceFirst('#', '0xFF')));
  Color get backgroundColor => Color(
      int.parse(backgroundColorHex.replaceFirst('#', '0xFF')));

  /// Light variant of theme color for backgrounds
  Color get themeColorLight => themeColor.withOpacity(0.12);

  /// Whether a logo URL is available
  bool get hasLogo => logoUrl.isNotEmpty;
  bool get hasBanner => bannerImageUrl.isNotEmpty;
  bool get isClaimed => ownerUid != null && ownerUid!.isNotEmpty;
  bool get hasFacebook => facebookUrl.isNotEmpty;
  bool get hasInstagram => instagramUrl.isNotEmpty;
  /// Whether the "Follow the Exhibitor" booth task has anything to show —
  /// at least one of Facebook/Instagram/Website is set.
  bool get hasFollowLinks =>
      hasFacebook || hasInstagram || website.isNotEmpty;

  /// Resolved config for one of the 6 generic games, falling back to
  /// enabled-by-default with that game's standard point value.
  BoothGameConfig configFor(String gameType) =>
      gameConfig[gameType] ?? BoothGameConfig.fromMap(null, gameType);

  factory ExhibitorModel.fromMap(String id, Map<String, dynamic> map) {
    final rawGameConfig =
        Map<String, dynamic>.from(map['gameConfig'] ?? {});
    return ExhibitorModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      website: map['website'] ?? '',
      facebookUrl: map['facebookUrl'] ?? '',
      instagramUrl: map['instagramUrl'] ?? '',
      themeColorHex: map['themeColorHex'] ?? '#6C63FF',
      boothNumber: map['boothNumber'] ?? '',
      category: map['category'] ?? 'General',
      tags: List<String>.from(map['tags'] ?? []),
      isSponsored: map['isSponsored'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
      ownerUid: map['ownerUid'] as String?,
      bannerImageUrl: map['bannerImageUrl'] ?? '',
      secondaryColorHex: map['secondaryColorHex'] ?? '#FF6584',
      backgroundColorHex: map['backgroundColorHex'] ?? '#F8F7FF',
      welcomeMessage: map['welcomeMessage'] ?? '',
      isActive: map['isActive'] ?? true,
      gameConfig: {
        for (final g in kGenericBoothGames)
          g.key: BoothGameConfig.fromMap(
              rawGameConfig[g.key] as Map<String, dynamic>?, g.key),
      },
      qrPresetStyle: map['qrPresetStyle'] ?? 'plain',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'website': website,
        'facebookUrl': facebookUrl,
        'instagramUrl': instagramUrl,
        'themeColorHex': themeColorHex,
        'boothNumber': boothNumber,
        'category': category,
        'tags': tags,
        'isSponsored': isSponsored,
        'createdAt': createdAt,
        'bannerImageUrl': bannerImageUrl,
        'secondaryColorHex': secondaryColorHex,
        'backgroundColorHex': backgroundColorHex,
        'welcomeMessage': welcomeMessage,
        'isActive': isActive,
        'gameConfig': {
          for (final entry in gameConfig.entries) entry.key: entry.value.toMap(),
        },
        'qrPresetStyle': qrPresetStyle,
        // Deliberately NOT included: ownerUid. It's set exactly once by the
        // invite-redemption transaction and must never be touched by a
        // regular booth-customization save — see FirestoreService.
      };

  /// The subset of fields an exhibitor may save from their own Booth
  /// Editor screen — excludes ownerUid/isActive/boothNumber/isSponsored,
  /// which are either fixed at creation or a Super-Admin-only concern.
  Map<String, dynamic> toCustomizationMap() => {
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'website': website,
        'facebookUrl': facebookUrl,
        'instagramUrl': instagramUrl,
        'themeColorHex': themeColorHex,
        'secondaryColorHex': secondaryColorHex,
        'backgroundColorHex': backgroundColorHex,
        'welcomeMessage': welcomeMessage,
        'qrPresetStyle': qrPresetStyle,
      };

  ExhibitorModel copyWith({
    String? name,
    String? description,
    String? logoUrl,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? facebookUrl,
    String? instagramUrl,
    String? themeColorHex,
    String? boothNumber,
    String? category,
    List<String>? tags,
    bool? isSponsored,
    String? ownerUid,
    String? bannerImageUrl,
    String? secondaryColorHex,
    String? backgroundColorHex,
    String? welcomeMessage,
    bool? isActive,
    Map<String, BoothGameConfig>? gameConfig,
    String? qrPresetStyle,
  }) =>
      ExhibitorModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        logoUrl: logoUrl ?? this.logoUrl,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        website: website ?? this.website,
        facebookUrl: facebookUrl ?? this.facebookUrl,
        instagramUrl: instagramUrl ?? this.instagramUrl,
        themeColorHex: themeColorHex ?? this.themeColorHex,
        boothNumber: boothNumber ?? this.boothNumber,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        isSponsored: isSponsored ?? this.isSponsored,
        createdAt: createdAt,
        ownerUid: ownerUid ?? this.ownerUid,
        bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
        secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
        backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
        welcomeMessage: welcomeMessage ?? this.welcomeMessage,
        isActive: isActive ?? this.isActive,
        gameConfig: gameConfig ?? this.gameConfig,
        qrPresetStyle: qrPresetStyle ?? this.qrPresetStyle,
      );
}
