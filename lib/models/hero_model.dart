class HeroModel {
  final String id;
  final Map<String, String> names;
  final List<String> roles;
  final String? imageAsset;
  final String? imageUrl;

  const HeroModel({
    required this.id,
    required this.names,
    required this.roles,
    this.imageAsset,
    this.imageUrl,
  });

  String name(String locale) => names[locale] ?? names['en'] ?? id;
}

const sampleHeroes = [
  HeroModel(
    id: 'fanny',
    names: {
      'tr': 'Fanny',
      'en': 'Fanny',
    },
    roles: ['Assassin'],
  ),
  HeroModel(
    id: 'miya',
    names: {
      'tr': 'Miya',
      'en': 'Miya',
    },
    roles: ['Marksman'],
  ),
  HeroModel(
    id: 'tigreal',
    names: {
      'tr': 'Tigreal',
      'en': 'Tigreal',
    },
    roles: ['Tank'],
  ),
];
