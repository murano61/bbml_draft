
enum FiveAnalysisState { empty, loading, result }

class HeroRole {
  final String name;
  final String laneLabel;
  final String iconPath;
  const HeroRole({required this.name, required this.laneLabel, required this.iconPath});
}

class HeroPick {
  final String heroName;
  final String? heroId;
  final HeroRole role;
  final String avatarPath;
  final bool isSTier;
  final String? imageUrl;
  const HeroPick({required this.heroName, this.heroId, required this.role, required this.avatarPath, this.isSTier = false, this.imageUrl});
}

enum MetricTab { general, strategy, metaDifficulty }

class Metric {
  final String title;
  final int score;
  final String description;
  const Metric({required this.title, required this.score, required this.description});
}

class AiSuggestion { final String text; const AiSuggestion(this.text); }

class Badge {
  final String name;
  final String description;
  final String iconPath;
  const Badge({required this.name, required this.description, required this.iconPath});
}

class FiveAnalysisResult {
  final int overallScore;
  final String tierLabel;
  final String tierSubtitle;
  final Map<MetricTab, List<Metric>> metrics;
  final List<AiSuggestion> suggestions;
  final List<Badge> badges;
  final int bestScore;
  final DateTime bestScoreDate;
  const FiveAnalysisResult({
    required this.overallScore,
    required this.tierLabel,
    required this.tierSubtitle,
    required this.metrics,
    required this.suggestions,
    required this.badges,
    required this.bestScore,
    required this.bestScoreDate,
  });
}
