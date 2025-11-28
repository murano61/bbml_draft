class CounterEntry {
  final String heroId;
  final String difficulty; // easy | medium | hard
  final Map<String, String> reason;

  const CounterEntry({
    required this.heroId,
    required this.difficulty,
    required this.reason,
  });
}

class CountersDoc {
  final String mainHeroId;
  final List<CounterEntry> counters;
  final List<CounterEntry> countered;

  const CountersDoc({required this.mainHeroId, required this.counters, this.countered = const []});
}

final localCounters = <String, CountersDoc>{
  'fanny': const CountersDoc(
    mainHeroId: 'fanny',
    counters: [
      CounterEntry(
        heroId: 'tigreal',
        difficulty: 'hard',
        reason: {
          'tr': 'Güçlü CC ve pozisyon kırma ile Fanny’i engeller.',
          'en': 'Strong CC to stop Fanny’s mobility.',
        },
      ),
      CounterEntry(
        heroId: 'miya',
        difficulty: 'medium',
        reason: {
          'tr': 'Safe farm ve pozisyon alma ile tehdit düzeyi azalır.',
          'en': 'Safe farm reduces threat level.',
        },
      ),
    ],
    countered: [
      CounterEntry(
        heroId: 'layla',
        difficulty: 'easy',
        reason: {
          'tr': 'Yavaş ve kaçışı zayıf kahramanlara karşı baskın olabilir.',
          'en': 'Strong against slow, low-escape heroes.',
        },
      ),
    ],
  ),
};

