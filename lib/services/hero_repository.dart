import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/hero_model.dart';
import '../models/counter_model.dart';
import '../models/search_log_model.dart';
import 'firebase_service.dart';

class HeroRepository {
  List<HeroModel> getHeroesLocal() => sampleHeroes;

  CountersDoc? countersLocalFor(String mainHeroId) => localCounters[mainHeroId];

  Future<CountersDoc?> countersFor(String mainHeroId, String locale) async {
    if (FirebaseService.isInitialized) {
      try {
        final doc = await FirebaseService.db.collection('counters').doc(mainHeroId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final List<dynamic> list = data['counters'] ?? [];
          final entries = list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final reason = <String, String>{
              'tr': (m['reason_tr'] ?? '').toString(),
              'en': (m['reason_en'] ?? '').toString(),
              'ru': (m['reason_ru'] ?? '').toString(),
              'id': (m['reason_id'] ?? '').toString(),
              'fil': (m['reason_fil'] ?? '').toString(),
            };
            return CounterEntry(
              heroId: (m['heroId'] ?? '').toString(),
              difficulty: (m['difficulty'] ?? 'medium').toString(),
              reason: reason,
            );
          }).toList();
          return CountersDoc(mainHeroId: mainHeroId, counters: entries);
        }
      } catch (_) {}
    }
    return countersLocalFor(mainHeroId);
  }

  final Map<String, String?> _imageUrlCache = {};
  Future<String?> heroImageUrl(String heroId) async {
    if (_imageUrlCache.containsKey(heroId)) return _imageUrlCache[heroId];
    if (!FirebaseService.isInitialized) return null;
    try {
      final doc = await FirebaseService.db.collection('heroes').doc(heroId).get();
      final url = (doc.data() ?? {})['imageUrl'] as String?;
      _imageUrlCache[heroId] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> logSearch(SearchLog log, {String? userId}) async {
    if (!FirebaseService.isInitialized) return;
    try {
      final uid = userId ?? 'local-device';
      await FirebaseService.db
          .collection('users')
          .doc(uid)
          .collection('search_logs')
          .add(log.toJson());

      final heroIds = [
        if (log.enemyHeroId != null) log.enemyHeroId!,
        if (log.mainHeroId != null) log.mainHeroId!,
      ];
      for (final id in heroIds) {
        final ref = FirebaseService.db.collection('hero_stats').doc(id);
        final data = <String, dynamic>{
          if (log.type == 'enemy_pick') 'searchCountEnemyPick': FieldValue.increment(1),
          if (log.type == 'my_counters') 'searchCountCounters': FieldValue.increment(1),
          'totalSearchCount': FieldValue.increment(1),
        };
        await ref.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('logSearch failed: $e');
    }
  }

  Future<void> seedSampleData() async {
    if (!FirebaseService.isInitialized) return;
    try {
      // Seed heroes
      for (final h in sampleHeroes) {
        final doc = FirebaseService.db.collection('heroes').doc(h.id);
        final exists = (await doc.get()).exists;
        if (!exists) {
          await doc.set({
            'id': h.id,
            'name_tr': h.names['tr'] ?? h.id,
            'name_en': h.names['en'] ?? h.id,
            'name_ru': h.names['ru'] ?? h.id,
            'name_id': h.names['id'] ?? h.id,
            'name_fil': h.names['fil'] ?? h.id,
            'roles': h.roles,
            'imageAsset': h.imageAsset ?? '',
            'imageUrl': h.imageUrl ?? '',
          });
        }
      }

      // Seed counters for fanny (from local)
      final fannyDoc = countersLocalFor('fanny');
      if (fannyDoc != null) {
        final doc = FirebaseService.db.collection('counters').doc('fanny');
        final exists = (await doc.get()).exists;
        if (!exists) {
          await doc.set({
            'counters': fannyDoc.counters.map((c) => {
                  'heroId': c.heroId,
                  'difficulty': c.difficulty,
                  'reason_tr': c.reason['tr'] ?? '',
                  'reason_en': c.reason['en'] ?? '',
                  'reason_ru': c.reason['ru'] ?? '',
                  'reason_id': c.reason['id'] ?? '',
                  'reason_fil': c.reason['fil'] ?? '',
                }).toList(),
          });
        }
      }

      // Seed hero_stats
      for (final h in sampleHeroes) {
        final ref = FirebaseService.db.collection('hero_stats').doc(h.id);
        await ref.set({
          'searchCountEnemyPick': 0,
          'searchCountCounters': 0,
          'totalSearchCount': 0,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('seedSampleData failed: $e');
    }
  }
}
