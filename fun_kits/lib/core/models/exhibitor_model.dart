import 'package:flutter/material.dart';

class ExhibitorModel {
  final String id;
  final String name;
  final String description;
  final String logoUrl;
  final String contactEmail;
  final String contactPhone;
  final String website;
  final String themeColorHex;
  final String boothNumber;
  final String category;
  final List<String> tags;
  final bool isSponsored;
  final DateTime? createdAt;

  ExhibitorModel({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl = '',
    required this.contactEmail,
    this.contactPhone = '',
    this.website = '',
    this.themeColorHex = '#6C63FF',
    this.boothNumber = '',
    this.category = 'General',
    this.tags = const [],
    this.isSponsored = false,
    this.createdAt,
  });

  /// Parse hex string to Flutter Color
  Color get themeColor => Color(
      int.parse(themeColorHex.replaceFirst('#', '0xFF')));

  /// Light variant of theme color for backgrounds
  Color get themeColorLight => themeColor.withOpacity(0.12);

  /// Whether a logo URL is available
  bool get hasLogo => logoUrl.isNotEmpty;

  factory ExhibitorModel.fromMap(String id, Map<String, dynamic> map) {
    return ExhibitorModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      contactEmail: map['contactEmail'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      website: map['website'] ?? '',
      themeColorHex: map['themeColorHex'] ?? '#6C63FF',
      boothNumber: map['boothNumber'] ?? '',
      category: map['category'] ?? 'General',
      tags: List<String>.from(map['tags'] ?? []),
      isSponsored: map['isSponsored'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'website': website,
        'themeColorHex': themeColorHex,
        'boothNumber': boothNumber,
        'category': category,
        'tags': tags,
        'isSponsored': isSponsored,
        'createdAt': createdAt,
      };

  ExhibitorModel copyWith({
    String? name,
    String? description,
    String? logoUrl,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? themeColorHex,
    String? boothNumber,
    String? category,
    List<String>? tags,
    bool? isSponsored,
  }) =>
      ExhibitorModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        logoUrl: logoUrl ?? this.logoUrl,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        website: website ?? this.website,
        themeColorHex: themeColorHex ?? this.themeColorHex,
        boothNumber: boothNumber ?? this.boothNumber,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        isSponsored: isSponsored ?? this.isSponsored,
        createdAt: createdAt,
      );
}
