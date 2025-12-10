class BuildModel {
  final int id;
  final String heroId;
  final String type;
  final List<int> itemIds;
  final List<Map<String, dynamic>> itemsRaw;
  final String? spell;
  final String? emblem;
  final String? note;
  BuildModel({required this.id, required this.heroId, required this.type, required this.itemIds, required this.itemsRaw, this.spell, this.emblem, this.note});
  factory BuildModel.fromJson(Map<String, dynamic> j){
    int parseInt(dynamic v){ if (v is int) return v; return int.tryParse('$v') ?? 0; }
    String pickType(Map<String, dynamic> m){ final t = (m['type'] ?? m['category'] ?? '').toString(); return t.isEmpty ? 'meta' : t; }
    String pickHero(Map<String, dynamic> m){ final id = (m['heroId'] ?? m['hero_id'] ?? m['hero'] ?? m['heroSlug'] ?? m['heroName'] ?? '').toString(); return id; }
    List<int> pickItemIds(dynamic v){
      if (v is List) {
        final out = <int>[]; for (final x in v){ out.add(parseInt(x)); } return out;
      }
      return const <int>[];
    }
    List<Map<String, dynamic>> pickItemsRaw(dynamic v){
      if (v is List) {
        return v.map((e){ if (e is Map) return Map<String, dynamic>.from(e); return <String, dynamic>{}; }).toList();
      }
      return const <Map<String, dynamic>>[];
    }
    final itemsField = j['items'] ?? j['slots'] ?? j['buildItems'];
    final idsField = j['itemIds'] ?? j['items_ids'] ?? j['itemsIds'];
    return BuildModel(
      id: parseInt(j['id']),
      heroId: pickHero(j),
      type: pickType(j),
      itemIds: idsField != null ? pickItemIds(idsField) : (itemsField is List && itemsField.isNotEmpty && itemsField.first is int ? pickItemIds(itemsField) : const <int>[]),
      itemsRaw: itemsField is List && itemsField.isNotEmpty && itemsField.first is Map ? pickItemsRaw(itemsField) : const <Map<String, dynamic>>[],
      spell: (j['spell'] ?? j['battleSpell'])?.toString(),
      emblem: (j['emblem'] ?? j['emblemName'])?.toString(),
      note: j['note']?.toString(),
    );
  }
}
