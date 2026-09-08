/// Represents the current state of a sliding puzzle tile
class PuzzleTile {
  final int value;    // 1-based tile number; 0 = empty
  final int index;    // current position in the grid (0-based)

  const PuzzleTile({required this.value, required this.index});

  bool get isEmpty => value == 0;

  PuzzleTile copyWith({int? value, int? index}) => PuzzleTile(
        value: value ?? this.value,
        index: index ?? this.index,
      );

  @override
  bool operator ==(Object other) =>
      other is PuzzleTile &&
      other.value == value &&
      other.index == index;

  @override
  int get hashCode => Object.hash(value, index);
}

/// Represents a puzzle configuration stored in Firestore
class PuzzleModel {
  final String id;
  final String exhibitorId;
  final String imageUrl;
  final String title;
  final int gridSize;       // 3 = 3×3 (8-tile), 4 = 4×4 (15-tile)
  final int pointsReward;
  final bool isActive;
  final DateTime? createdAt;

  PuzzleModel({
    required this.id,
    required this.exhibitorId,
    this.imageUrl = '',
    this.title = 'Slide Puzzle',
    this.gridSize = 3,
    this.pointsReward = 50,
    this.isActive = true,
    this.createdAt,
  });

  /// Total tiles including empty slot
  int get totalTiles => gridSize * gridSize;

  /// Maximum numbered tiles
  int get maxTileValue => totalTiles - 1;

  /// Whether a background image is provided
  bool get hasImage => imageUrl.isNotEmpty;

  /// Points awarded based on move count (fewer = more points)
  int calculatePoints(int moves) {
    if (moves <= 20) return pointsReward;
    if (moves <= 40) return (pointsReward * 0.75).round();
    if (moves <= 60) return (pointsReward * 0.5).round();
    return (pointsReward * 0.25).round().clamp(5, pointsReward);
  }

  factory PuzzleModel.fromMap(String id, Map<String, dynamic> map) =>
      PuzzleModel(
        id: id,
        exhibitorId: map['exhibitorId'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        title: map['title'] ?? 'Slide Puzzle',
        gridSize: map['gridSize'] ?? 3,
        pointsReward: map['pointsReward'] ?? 50,
        isActive: map['isActive'] ?? true,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'exhibitorId': exhibitorId,
        'imageUrl': imageUrl,
        'title': title,
        'gridSize': gridSize,
        'pointsReward': pointsReward,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  PuzzleModel copyWith({
    String? exhibitorId,
    String? imageUrl,
    String? title,
    int? gridSize,
    int? pointsReward,
    bool? isActive,
  }) =>
      PuzzleModel(
        id: id,
        exhibitorId: exhibitorId ?? this.exhibitorId,
        imageUrl: imageUrl ?? this.imageUrl,
        title: title ?? this.title,
        gridSize: gridSize ?? this.gridSize,
        pointsReward: pointsReward ?? this.pointsReward,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
