class TeamScore {
  final int left;
  final int right;
  TeamScore({required this.left, required this.right});
}

class LaneMatchup {
  final String lane;
  final String allyHeroId;
  final String enemyHeroId;
  final int leftScore;
  final int rightScore;
  final String description;
  LaneMatchup({required this.lane, required this.allyHeroId, required this.enemyHeroId, required this.leftScore, required this.rightScore, required this.description});
}

class SynergyMetricItem {
  final String name;
  final int left;
  final int right;
  SynergyMetricItem({required this.name, required this.left, required this.right});
}

class MetaScores {
  final int ally;
  final int enemy;
  final int early;
  final int mid;
  final int late;
  MetaScores({required this.ally, required this.enemy, required this.early, required this.mid, required this.late});
}

class CompositionAspectItem {
  final String name;
  final int left;
  final int right;
  CompositionAspectItem({required this.name, required this.left, required this.right});
}

class EvaluationPlan {
  final String winner;
  final String early;
  final String mid;
  final String late;
  EvaluationPlan({required this.winner, required this.early, required this.mid, required this.late});
}
