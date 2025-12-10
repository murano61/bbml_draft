import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/hero_model.dart';
import '../models/counter_model.dart';
import '../models/search_log_model.dart';
import 'firebase_service.dart';

class HeroRepository {
  static List<HeroModel>? _heroesCache;
  static DateTime? _heroesCacheAt;
  List<HeroModel> getHeroesLocal() => sampleHeroes;

  Future<List<HeroModel>> getHeroes() async {
    final now = DateTime.now();
    if (_heroesCache != null && _heroesCacheAt != null && now.difference(_heroesCacheAt!).inMinutes < 10) {
      return _heroesCache!;
    }
    if (!FirebaseService.isInitialized) return _heroesCache ?? getHeroesLocal();
    try {
      final snap = await FirebaseService.db.collection('heroes').get();
      final list = snap.docs.map((d) {
        final m = d.data();
        return HeroModel(
          id: (m['id'] ?? d.id).toString(),
          names: {
            'tr': (m['name_tr'] ?? '').toString(),
            'en': (m['name_en'] ?? '').toString(),
            'ru': (m['name_ru'] ?? '').toString(),
            'id': (m['name_id'] ?? '').toString(),
            'fil': (m['name_fil'] ?? '').toString(),
          },
          roles: List<String>.from((m['roles'] ?? []) as List),
          lanes: List<String>.from((m['lanes'] ?? []) as List),
          imageUrl: (m['imageUrl'] ?? '').toString(),
        );
      }).toList();
      _heroesCache = list;
      _heroesCacheAt = now;
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload = jsonEncode(list.map((e) => e.toMap()).toList());
        await prefs.setString('heroes_cache_v1', payload);
        await prefs.setInt('heroes_cache_v1_at', now.millisecondsSinceEpoch);
      } catch (_) {}
      return list;
    } catch (_) {
      return _heroesCache ?? getHeroesLocal();
    }
  }

  Future<List<HeroModel>> getHeroesCached() async {
    if (_heroesCache != null) return _heroesCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('heroes_cache_v1');
      if (s != null && s.isNotEmpty) {
        final list = (jsonDecode(s) as List).map((e) => HeroModel.fromMap(Map<String, dynamic>.from(e))).toList();
        _heroesCache = list;
        final atMs = prefs.getInt('heroes_cache_v1_at');
        _heroesCacheAt = atMs != null ? DateTime.fromMillisecondsSinceEpoch(atMs) : DateTime.now();
        return list;
      }
    } catch (_) {}
    return const [];
  }

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
          final List<dynamic> listCountered = data['countered'] ?? [];
          final counteredEntries = listCountered.map((e) {
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
              difficulty: (m['difficulty'] ?? 'easy').toString(),
              reason: reason,
            );
          }).toList();
          return CountersDoc(mainHeroId: mainHeroId, counters: entries, countered: counteredEntries);
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

  Future<void> seedSampleData() async {}
}
