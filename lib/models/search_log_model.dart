class SearchLog {
  final String type; // enemy_pick | my_counters
  final String? enemyHeroId;
  final String? mainHeroId;
  final String? role;
  final List<String>? playStyle;
  final DateTime createdAt;

  const SearchLog({
    required this.type,
    this.enemyHeroId,
    this.mainHeroId,
    this.role,
    this.playStyle,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'enemyHeroId': enemyHeroId,
        'mainHeroId': mainHeroId,
        'role': role,
        'playStyle': playStyle,
        'createdAt': createdAt.toIso8601String(),
      };
}

