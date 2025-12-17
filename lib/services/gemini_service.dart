import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hero_model.dart';
import 'hero_repository.dart';

class AiSuggestionEntry {
  final String heroId;
  final String reason;
  final String difficulty;
  AiSuggestionEntry({required this.heroId, required this.reason, this.difficulty = 'Orta'});
}

class GeminiService {
  static Map<String, dynamic> _lastMem = {'source': '', 'model': '', 'len': 0, 'ts': 0, 'err': ''};
  static const _prefApiKey = 'geminiApiKey';
  static const _cachePrefix = 'ai_cache_v1:';
  static const _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  // legacy prefs keys removed; using in-memory status only

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key);
  }
  Future<String?> getApiKey() async {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey);
  }

  Future<String> generateChallenge({required List<String> roles, required String locale, int timeoutMs = 6000}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await _setLastStatus('error', model: '', len: 0);
      await _setLastError('no_api_key');
      return '';
    }
    const model = 'gemini-2.0-flash';
    final gm = GenerativeModel(
      model: model,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.6, topP: 0.95, maxOutputTokens: 64),
    );
    final lanes = roles.join(', ');
    String langName(String lc) {
      switch (lc) {
        case 'tr': return 'Turkish';
        case 'en': return 'English';
        case 'ru': return 'Russian';
        case 'id': return 'Indonesian';
        case 'fil': return 'Filipino';
        default: return 'English';
      }
    }
    final prompt = 'Give ONE short Mobile Legends challenge for lanes [$lanes] in ${langName(locale)}. 8–12 words. Respond ONLY in ${langName(locale)} without any other language words.';
    try {
      final res = await gm.generateContent([Content.text(prompt)])
          .timeout(Duration(milliseconds: timeoutMs));
      final txt = res.text ?? '';
      await _setLastStatus('gemini', model: model, len: txt.length);
      await _setLastError('');
      return txt.trim();
    } on TimeoutException catch (e) {
      await _setLastStatus('error', model: model, len: 0);
      await _setLastError('timeout:${e.message ?? ''}');
      return '';
    } catch (e) {
      await _setLastStatus('error', model: model, len: 0);
      await _setLastError('exception:${e.toString()}');
      return '';
    }
  }

  Future<String?> _getApiKey() async {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey);
  }

  Future<bool> hasApiKey() async {
    final k = await _getApiKey();
    return k != null && k.isNotEmpty;
  }

  String _key(String? enemyHeroId, List<String> roles, String locale) {
    final r = [...roles]..sort();
    return '$_cachePrefix${enemyHeroId ?? 'direct'}:${r.join(',')}:$locale';
  }

  Future<List<AiSuggestionEntry>?> getCached(String? enemyHeroId, List<String> roles, String locale) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key(enemyHeroId, roles, locale));
    if (s == null || s.isEmpty) return null;
    try {
      final repo = HeroRepository();
      final heroes = await repo.getHeroesCached();
      return _parseToEntries(s, heroes, locale);
    } catch (_) {
      return null;
    }
  }

  Future<void> setCached(String? enemyHeroId, List<String> roles, String locale, String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(enemyHeroId, roles, locale), raw);
  }

  Future<int> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
    return keys.length;
  }

  Future<void> _setLastStatus(String source, {String? model, int? len}) async {
    _lastMem = {
      'source': source,
      'model': model ?? '',
      'len': len ?? 0,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'err': _lastMem['err'] ?? '',
    };
  }

  Future<void> _setLastError(String? error) async {
    _lastMem['err'] = error ?? '';
  }

  Future<void> setLastStatusPublic(String source, {String? model, int? len, String? err}) async {
    await _setLastStatus(source, model: model, len: len);
    await _setLastError(err ?? '');
  }

  Future<List<AiSuggestionEntry>> suggest({String? enemyHeroId, required List<String> roles, required String locale, bool noCache = false, String? nonce, List<String> excludeHeroIds = const [], int timeoutMs = 12000, bool requireGemini = false}) async {
    if (!noCache) {
      final cached = await getCached(enemyHeroId, roles, locale);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await _setLastStatus('config', model: null, len: 0);
      await _setLastError('no_api_key');
      return [];
    }
    final repo = HeroRepository();
    var heroes = await repo.getHeroesCached();
    if (heroes.isEmpty) heroes = await repo.getHeroes();
    if (heroes.isEmpty) heroes = sampleHeroes;
    final selectedRoles = roles.map((r) => r.toLowerCase()).toSet();
    final laneKeywords = {'gold', 'exp', 'jungle', 'mid', 'roam'};
    final selectedLanes = selectedRoles.intersection(laneKeywords);
    List<HeroModel> allowedHeroes = selectedRoles.isEmpty
        ? heroes
        : (selectedLanes.isNotEmpty
            ? heroes.where((h) => h.lanes.map((x) => x.toLowerCase()).toSet().intersection(selectedLanes).isNotEmpty).toList()
            : heroes.where((h) => h.roles.map((x) => x.toLowerCase()).toSet().intersection(selectedRoles).isNotEmpty).toList());
    if (allowedHeroes.isEmpty) {
      // Relax filters if lane-based selection yields no heroes
      allowedHeroes = heroes.where((h) => h.roles.map((x) => x.toLowerCase()).toSet().intersection(selectedRoles).isNotEmpty).toList();
      if (allowedHeroes.isEmpty) allowedHeroes = heroes;
    }
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final excludedSet = excludeHeroIds.toSet();
    final basePool = allowedHeroes.isNotEmpty ? [...allowedHeroes] : [...heroes];
    var pool = basePool.where((h) => !excludedSet.contains(h.id)).toList()..shuffle(rng);
    if (enemyHeroId != null && enemyHeroId.isNotEmpty) {
      pool = pool.where((h) => h.id != enemyHeroId).toList();
    }
    final namesLocale = pool.map((h) => h.name(locale)).toList();
    final namesEn = pool.map((h) => h.name('en')).toList();
    final names = {...namesLocale, ...namesEn}.toList().take(60).toList();

    final prompt = StringBuffer()
      ..writeln('Task: Suggest 3 Mobile Legends heroes against enemy.')
      ..writeln('Enemy hero: ${enemyHeroId ?? 'none'}')
      ..writeln('Preferred lanes/roles: ${roles.join(', ')}')
      ..writeln('Do NOT suggest the enemy hero. Avoid duplicates.')
      ..writeln('Pick ONLY from this allowed names list: ${names.isNotEmpty ? names.join(', ') : 'use valid ML hero names'}')
      ..writeln('Output EXACTLY valid JSON without code fences: {"suggestions":[{"hero":"<name>","reason":"<one short sentence in ${locale.toUpperCase()}, 8-20 words>"},{...},{...}]}')
      ..writeln('Do NOT use placeholders like generic_reason, N/A. Provide real matchup reasoning. If unsure, choose a different hero.');
    if (nonce != null && nonce.isNotEmpty) {
      prompt.writeln('Variation token: $nonce');
    }
    final simplePrompt = StringBuffer()
      ..writeln('Enemy hero: ${enemyHeroId ?? 'none'}; lanes/roles: ${roles.join(', ')}')
      ..writeln('From allowed: ${names.join(', ')}; avoid enemy hero and duplicates.')
      ..writeln('Output 3 lines: Name | short reason (${locale.toUpperCase()})');

    final models = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ];
    final startMs = DateTime.now().millisecondsSinceEpoch;
    final completer = Completer<List<AiSuggestionEntry>>();
    bool done = false;
    await _setLastError('');
    String finalSource = '';
    String? finalModel;
    int finalLen = 0;
    Future<void> tryModel(String m) async {
      String raw = '';
      try {
        if (done) return;
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        final remaining = timeoutMs - elapsed;
        if (remaining <= 1500) return;
        final gm = GenerativeModel(
          model: m,
          apiKey: apiKey,
          generationConfig: GenerationConfig(temperature: 0.2, topP: 0.95, maxOutputTokens: 768),
          safetySettings: [
            SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
          ],
        );
        final res = await gm.generateContent([Content.text(prompt.toString())])
            .timeout(Duration(milliseconds: remaining));
        if (res.candidates.isNotEmpty) {
          final parts = res.candidates.first.content.parts;
          final texts = <String>[];
          for (final p in parts) {
            if (p is TextPart) {
              final t = p.text;
              if (t.isNotEmpty) texts.add(t);
            }
          }
          raw = texts.join('\n');
          if (raw.isEmpty) {
            final t = res.text;
            if (t != null && t.isNotEmpty) raw = t;
          }
        } else {
          raw = res.text ?? '';
        }
        final looksLikeModelError = RegExp(r"models\/.* is not found", caseSensitive: false).hasMatch(raw);
        final overloaded = RegExp(r"overloaded|try again later", caseSensitive: false).hasMatch(raw);
        if (looksLikeModelError || overloaded || raw.isEmpty) {
          if (!done) {
            await _setLastStatus('error', model: m, len: 0);
            await _setLastError(raw.isEmpty ? 'empty' : raw);
          }
          if (overloaded) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
          return;
        }
        var candidate = _parseToEntries(raw, allowedHeroes, locale, banNameNorm: enemyHeroId?.toLowerCase());
        if (selectedRoles.isNotEmpty) {
          candidate = candidate.where((e) {
            final h = heroes.firstWhere((x) => x.id == e.heroId, orElse: () => HeroModel(id: e.heroId, names: {'en': e.heroId}, roles: const []));
            final hr = h.roles.map((x) => x.toLowerCase()).toSet();
            final hl = h.lanes.map((x) => x.toLowerCase()).toSet();
            return (selectedLanes.isNotEmpty ? hl.intersection(selectedLanes).isNotEmpty : hr.intersection(selectedRoles).isNotEmpty);
          }).toList();
        }
        if (excludeHeroIds.isNotEmpty) {
          final ex = excludeHeroIds.toSet();
          candidate = candidate.where((e) => !ex.contains(e.heroId)).toList();
        }
        if (candidate.isNotEmpty) {
          if (!completer.isCompleted) {
            finalSource = 'gemini';
            finalModel = m;
            finalLen = raw.length;
            if (!requireGemini && !noCache) {
              await setCached(enemyHeroId, roles, locale, raw);
            }
            done = true;
            completer.complete(candidate.take(3).toList());
          }
        } else {
          if (!done) {
            // keep trying other models; do not write status yet
          }
        }
      } on TimeoutException catch (e) {
        if (!done) {
          await _setLastStatus('error', model: m, len: 0);
          await _setLastError('timeout:${e.message ?? ''}');
        }
        return;
      } catch (e) {
        if (!done) {
          await _setLastStatus('error', model: m, len: 0);
          await _setLastError('exception:${e.toString()}');
        }
        return;
      }
    }
    for (final m in models) { unawaited(tryModel(m)); }
    List<AiSuggestionEntry> entriesList = const [];
    try {
      entriesList = await completer.future.timeout(Duration(milliseconds: timeoutMs));
    } catch (_) {}
    if (entriesList.isEmpty) {
      final start2 = DateTime.now().millisecondsSinceEpoch;
      Future<void> tryModelSimple(String m) async {
        try {
          if (done) return;
          final elapsed = DateTime.now().millisecondsSinceEpoch - start2;
          final remaining = timeoutMs - elapsed;
          if (remaining <= 500) return;
          final gm = GenerativeModel(model: m, apiKey: apiKey, generationConfig: GenerationConfig(temperature: 0.2, topP: 0.95, maxOutputTokens: 256));
          final res = await gm.generateContent([Content.text(simplePrompt.toString())]).timeout(Duration(milliseconds: remaining));
          final raw = (res.text ?? '').isNotEmpty ? res.text! : '';
          var candidate = raw.isNotEmpty ? _parseToEntries(raw, allowedHeroes, locale, banNameNorm: enemyHeroId?.toLowerCase()) : const <AiSuggestionEntry>[];
          if (candidate.isNotEmpty && !completer.isCompleted) {
            finalSource = 'gemini';
            finalModel = m;
            finalLen = raw.length;
            done = true;
            entriesList = candidate.take(3).toList();
          }
        } catch (_) {}
      }
      for (final m in models) { await tryModelSimple(m); }
    }
    // Filter by selected lanes/roles
    if (selectedRoles.isNotEmpty) {
      entriesList = entriesList.where((e) {
        final h = heroes.firstWhere((x) => x.id == e.heroId, orElse: () => HeroModel(id: e.heroId, names: {'en': e.heroId}, roles: const []));
        final hr = h.roles.map((x) => x.toLowerCase()).toSet();
        final hl = h.lanes.map((x) => x.toLowerCase()).toSet();
        return (selectedLanes.isNotEmpty ? hl.intersection(selectedLanes).isNotEmpty : hr.intersection(selectedRoles).isNotEmpty);
      }).toList();
    }
    if (excludeHeroIds.isNotEmpty) {
      final ex = excludeHeroIds.toSet();
      entriesList = entriesList.where((e) => !ex.contains(e.heroId)).toList();
    }
    if (!requireGemini) {
      if (entriesList.length < 3) {
        final fb = await _fallbackSuggestions(repo, enemyHeroId, heroes, locale, selectedRoles, need: 3 - entriesList.length, nonce: nonce, excludeHeroIds: excludeHeroIds);
        entriesList.addAll(fb);
        if (fb.isNotEmpty) {
          done = true;
          finalSource = 'fallback';
          finalModel = null;
          finalLen = 0;
        }
      }
    } else {
      if (finalSource != 'gemini') {
        await _setLastStatus('error', model: finalModel, len: finalLen);
        await _setLastError('gemini_only');
        entriesList = const [];
      }
    }
    if (entriesList.isEmpty) {
      finalSource = finalSource.isEmpty ? 'error' : finalSource;
    }
    // Improve reasons using counters/doc data or simple heuristics
    if (enemyHeroId != null && enemyHeroId.isNotEmpty && entriesList.isNotEmpty) {
      try {
        final counters = await repo.countersFor(enemyHeroId, locale);
        entriesList = entriesList.map((e) {
          if (e.reason.trim().isEmpty || e.reason.trim().toLowerCase() == 'generic_reason') {
            String r = '';
            if (counters != null) {
              for (final c in counters.counters) {
                if (c.heroId.toLowerCase() == e.heroId.toLowerCase()) {
                  r = c.reason[locale] ?? c.reason['en'] ?? '';
                  break;
                }
              }
            }
            if (r.isNotEmpty) {
              return AiSuggestionEntry(heroId: e.heroId, reason: r, difficulty: e.difficulty);
            }
            // simple heuristic fallback
            return AiSuggestionEntry(heroId: e.heroId, reason: 'Bu kahramanın kontrol ve yetenek seti rakip kompozisyona karşı etkilidir.', difficulty: e.difficulty);
          }
          return e;
        }).toList();
      } catch (_) {}
    }
    await _setLastStatus(finalSource.isEmpty ? (requireGemini ? 'error' : 'fallback') : finalSource, model: finalModel, len: finalLen);
    if (((_lastMem['err'] ?? '') as String).isEmpty && entriesList.isEmpty) {
      await _setLastError('no_entries');
    }
    return entriesList.take(3).toList();
  }

  List<AiSuggestionEntry> _parseToEntries(String raw, List<HeroModel> heroes, String locale, {String? banNameNorm}) {
    final out = <AiSuggestionEntry>[];
    HeroModel? findHeroByName(String name) {
      final n = name.trim();
      if (n.isEmpty) return null;
      String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final nn = norm(n);
      for (final h in heroes) {
        final ln = norm(h.name(locale));
        if (ln == nn || ln.contains(nn) || nn.contains(ln)) return h;
        final en = norm(h.name('en'));
        if (en == nn || en.contains(nn) || nn.contains(en)) return h;
      }
      return null;
    }
    try {
      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        final m = RegExp(r"\{[\s\S]*?\}", multiLine: true).firstMatch(raw);
        if (m != null) {
          try { decoded = jsonDecode(m.group(0)!); } catch (_) {}
        }
      }
      final list = decoded is Map<String, dynamic> ? decoded['suggestions'] : decoded;
      if (list is List) {
        for (final item in list.take(3)) {
          final m = item is Map ? Map<String, dynamic>.from(item) : {};
          final name = (m['hero'] ?? '').toString();
          final reason = (m['reason'] ?? '').toString();
          if (name.isEmpty) continue;
          final hero = findHeroByName(name);
          if (hero == null) {
            if (banNameNorm != null) {
              String normName(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
              if (normName(name) == banNameNorm) continue;
            }
            final badReason = reason.trim().isEmpty || RegExp(r'\{|\}|"hero"\s*:', caseSensitive: false).hasMatch(reason);
            out.add(AiSuggestionEntry(heroId: name.trim(), reason: badReason ? 'generic_reason' : reason));
            continue;
          }
          final badReason = reason.trim().isEmpty || RegExp(r'\{|\}|"hero"\s*:', caseSensitive: false).hasMatch(reason);
          out.add(AiSuggestionEntry(heroId: hero.id, reason: badReason ? 'generic_reason' : reason));
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
    for (var l in lines) {
      var s = l.trim();
      s = s.replaceFirst(RegExp(r'^\d+[\.|\)]\s*'), '');
      String name = '';
      String reason = '';
      if (s.contains('|')) {
        final parts = s.split('|');
        name = parts[0].trim();
        reason = parts.length > 1 ? parts[1].trim() : '';
      } else {
        for (final h in heroes) {
          final ln = h.name(locale).toLowerCase();
          final en = h.name('en').toLowerCase();
          if (s.toLowerCase().contains(ln)) { name = h.name(locale); break; }
          if (s.toLowerCase().contains(en)) { name = h.name('en'); break; }
        }
        if (name.isNotEmpty) {
          reason = s.replaceAll(name, '').trim();
        }
      }
      if (name.isEmpty) continue;
      final hero = findHeroByName(name);
      if (hero == null) {
        if (banNameNorm != null) {
          String normName(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (normName(name) == banNameNorm) continue;
        }
        final badReason = reason.trim().isEmpty || RegExp(r'\{|\}|"hero"\s*:', caseSensitive: false).hasMatch(reason);
        out.add(AiSuggestionEntry(heroId: name.trim(), reason: badReason ? 'generic_reason' : reason));
        continue;
      }
      final badReason = reason.trim().isEmpty || RegExp(r'\{|\}|"hero"\s*:', caseSensitive: false).hasMatch(reason);
      out.add(AiSuggestionEntry(heroId: hero.id, reason: badReason ? 'generic_reason' : reason));
    }
    if (out.isEmpty) {
      final lower = raw.toLowerCase();
      for (final h in heroes) {
        final ln = h.name(locale).toLowerCase();
        final en = h.name('en').toLowerCase();
        if (lower.contains(ln) || lower.contains(en)) {
          out.add(AiSuggestionEntry(heroId: h.id, reason: 'generic_reason'));
          if (out.length >= 3) break;
        }
      }
    }
    return out;
  }

  Future<List<AiSuggestionEntry>> _fallbackSuggestions(
    HeroRepository repo,
    String? enemyHeroId,
    List<HeroModel> heroes,
    String locale,
    Set<String> selectedRoles,
    {int need = 3, String? nonce, List<String> excludeHeroIds = const []}
  ) async {
    final out = <AiSuggestionEntry>[];
    final seed = DateTime.now().millisecondsSinceEpoch ^ (nonce?.hashCode ?? 0);
    final rng = Random(seed);
    final ex = excludeHeroIds.toSet();
    if (enemyHeroId != null && enemyHeroId.isNotEmpty) {
      final counters = await repo.countersFor(enemyHeroId, locale);
      final list = counters?.counters ?? const [];
      // Prefer hard -> medium -> easy
      final hard = list.where((c) => c.difficulty.toLowerCase() == 'hard').toList();
      final medium = list.where((c) => c.difficulty.toLowerCase() == 'medium').toList();
      final easy = list.where((c) => c.difficulty.toLowerCase() == 'easy').toList();
      hard.shuffle(rng); medium.shuffle(rng); easy.shuffle(rng);
      final merged = [...hard, ...medium, ...easy];
      for (final c in merged) {
        final h = heroes.firstWhere((x) => x.id == c.heroId, orElse: () => HeroModel(id: c.heroId, names: {'en': c.heroId}, roles: const []));
        final laneKeywords = {'gold', 'exp', 'jungle', 'mid', 'roam'};
        final selectedLanes = selectedRoles.intersection(laneKeywords);
        final okRole = selectedRoles.isEmpty
            || (selectedLanes.isNotEmpty
                ? h.lanes.map((x) => x.toLowerCase()).toSet().intersection(selectedLanes).isNotEmpty
                : h.roles.map((x) => x.toLowerCase()).toSet().intersection(selectedRoles).isNotEmpty);
        if (!okRole) continue;
        if (ex.contains(h.id)) continue;
        final reason = c.reason[locale] ?? c.reason['en'] ?? '';
        out.add(AiSuggestionEntry(heroId: h.id, reason: reason.isEmpty ? 'generic_reason' : reason));
        if (out.length >= need) break;
      }
    }
    if (out.length < need) {
      // Direct pick top heroes by role if counters insufficient
      final laneKeywords = {'gold', 'exp', 'jungle', 'mid', 'roam'};
      final selectedLanes = selectedRoles.intersection(laneKeywords);
      final pool = selectedRoles.isNotEmpty
          ? (selectedLanes.isNotEmpty
              ? heroes.where((h) => h.lanes.map((x) => x.toLowerCase()).toSet().intersection(selectedLanes).isNotEmpty).toList()
              : heroes.where((h) => h.roles.map((x) => x.toLowerCase()).toSet().intersection(selectedRoles).isNotEmpty).toList())
          : [...heroes];
      pool.shuffle(rng);
      for (final h in pool) {
        if (ex.contains(h.id)) continue;
        out.add(AiSuggestionEntry(heroId: h.id, reason: 'generic_reason'));
        if (out.length >= need) break;
      }
    }
    return out;
  }

  Future<Map<String, dynamic>> getLastStatus() async {
    return Map<String, dynamic>.from(_lastMem);
  }
}
