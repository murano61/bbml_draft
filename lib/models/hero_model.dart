class HeroModel {
  final String id;
  final Map<String, String> names;
  final List<String> roles;
  final List<String> lanes;
  final String? imageAsset;
  final String? imageUrl;

  const HeroModel({
    required this.id,
    required this.names,
    required this.roles,
    this.lanes = const [],
    this.imageAsset,
    this.imageUrl,
  });

  String name(String locale) => names[locale] ?? names['en'] ?? id;

  factory HeroModel.fromMap(Map<String, dynamic> m) {
    return HeroModel(
      id: (m['id'] ?? '').toString(),
      names: Map<String, String>.from(m['names'] ?? {}),
      roles: List<String>.from(m['roles'] ?? []),
      lanes: List<String>.from(m['lanes'] ?? []),
      imageAsset: m['imageAsset'] as String?,
      imageUrl: m['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'names': names,
        'roles': roles,
        'lanes': lanes,
        'imageAsset': imageAsset,
        'imageUrl': imageUrl,
      };
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
