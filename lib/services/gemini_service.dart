import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
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

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key);
  }

  Future<String?> getApiKey() async {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey);
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

  Future<Map<String, dynamic>> getLastStatus() async {
    return Map<String, dynamic>.from(_lastMem);
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

  Future<List<AiSuggestionEntry>> suggest({String? enemyHeroId, required List<String> roles, required String locale, bool noCache = false, String? nonce, List<String> excludeHeroIds = const [], int timeoutMs = 25000, bool requireGemini = false}) async {
    if (!noCache) {
      final cached = await getCached(enemyHeroId, roles, locale);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final apiKey = await _getApiKey();
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
    if (apiKey == null || apiKey.isEmpty) {
      if (!requireGemini) {
        final fb = await _fallbackSuggestions(repo, enemyHeroId, heroes, locale, selectedRoles, need: 3, nonce: nonce, excludeHeroIds: excludeHeroIds);
        await _setLastStatus('fallback', model: null, len: 0);
        await _setLastError('no_api_key');
        return fb.take(3).toList();
      } else {
        await _setLastStatus('error', model: null, len: 0);
        await _setLastError('no_api_key');
        return const [];
      }
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
        if (remaining <= 500) return;
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
        final res = await gm.generateContent([Content.text(prompt.toString())]).timeout(Duration(milliseconds: remaining));
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

  Future<Map<String, dynamic>?> generateBuild({required String heroName, required String role, required String locale, required List<String> allowedItemNames, int timeoutMs = 24000}) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;
    final names = allowedItemNames.toSet().toList();
    final listShort = names.take(180).toList();
    final prompt = StringBuffer()
      ..writeln('Task: Generate two Mobile Legends build lists for the hero "$heroName" role "$role".')
      ..writeln('Output language: ${locale.toUpperCase()}')
      ..writeln('You MUST ONLY use item names from this allowed list: ${listShort.join(', ')}')
      ..writeln('Output EXACT JSON without code fences: {"meta_build":{"items":["name1","name2","name3","name4","name5","name6"],"spell":"SpellName","emblem":"EmblemName"},"fun_build":{"items":["name1","name2","name3","name4","name5","name6"],"note":"short note"}}');
    final gm = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey, generationConfig: GenerationConfig(temperature: 0.25, topP: 0.95, maxOutputTokens: 512));
    try {
      final res = await gm.generateContent([Content.text(prompt.toString())]).timeout(Duration(milliseconds: timeoutMs));
      String raw = '';
      if (res.candidates.isNotEmpty) {
        final parts = res.candidates.first.content.parts;
        for (final p in parts) { if (p is TextPart) { final t = p.text; if (t.isNotEmpty) raw += t; } }
      }
      if (raw.isEmpty) raw = res.text ?? '';
      raw = raw.trim();
      if (raw.isEmpty) return null;
      Map<String, dynamic> m;
      try {
        m = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        final start = raw.indexOf('{');
        final end = raw.lastIndexOf('}');
        if (start >= 0 && end > start) {
          m = Map<String, dynamic>.from(jsonDecode(raw.substring(start, end + 1)));
        } else {
          return null;
        }
      }
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeFive({required List<String> heroes, required List<String> lanes, required String locale, int timeoutMs = 18000}) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await _setLastStatus('error', model: '', len: 0);
      await _setLastError('no_api_key');
      return null;
    }
    const model = 'gemini-pro';
    final gm = GenerativeModel(
      model: model,
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.3, topP: 0.95, maxOutputTokens: 768),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
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
    final h = heroes.join(', ');
    final l = lanes.join(', ');
    final prompt = StringBuffer()
      ..writeln('Analyze a Mobile Legends team of 5 heroes: [$h]. Lanes/Roles: [$l].')
      ..writeln('Respond ONLY in ${langName(locale)}.')
      ..writeln('Score fields must be integers between 0 and 100.')
      ..writeln('Use a strict rubric: weak synergy or off-meta picks should score 25–55 overall; average 56–74; strong 75–89; S-tier 90–100. Do NOT be optimistic. Be critical and realistic.')
      ..writeln('IMPORTANT: Per-metric scores MUST vary based on the given heroes and lanes. Do NOT default to 80–90 range. Do NOT repeat the same number across many metrics. If composition is weak, several metrics MUST be in 25–55 range with clear reasons.')
      ..writeln('Avoid placeholders like 85/100 or generic text. Each metric must have a specific rationale tied to the team picks and lane assignments.')
      ..writeln('Provide detailed metrics: at least 6 items for "genel", at least 6 for "strateji", and at least 4 for "meta_zorluk".')
      ..writeln('Provide at least 5 short actionable suggestions (8–16 words).')
      ..writeln('Output EXACT valid JSON without code fences. Do NOT include explanations outside JSON. Do NOT copy example values below; they are placeholders only.')
      ..writeln('{')
      ..writeln('  "genel": [ {"title": "Rol Dengesi & Kompozisyon", "score": 0, "desc": "..."} ],')
      ..writeln('  "strateji": [ {"title": "Early Oyun Gücü", "score": 0, "desc": "..."} ],')
      ..writeln('  "meta_zorluk": [ {"title": "Meta Uyumu & Counter Potansiyeli", "score": 0, "desc": "..."} ],')
      ..writeln('  "overall_score": 0,')
      ..writeln('  "tier_label": "Tier: S/A/B/C/D",')
      ..writeln('  "tier_subtitle": "Short subtitle",')
      ..writeln('  "suggestions": ["Kısa taktik 1", "Kısa taktik 2", "Kısa taktik 3", "Kısa taktik 4", "Kısa taktik 5"]')
      ..writeln('}');
    try {
      final res = await gm.generateContent([Content.text(prompt.toString())]).timeout(Duration(milliseconds: timeoutMs));
      var raw = res.text ?? '';
      if (raw.isEmpty && res.candidates.isNotEmpty) {
        final parts = res.candidates.first.content.parts;
        for (final p in parts) { if (p is TextPart) { raw += p.text; } }
      }
      dynamic decoded;
      try { decoded = jsonDecode(raw); } catch (_) {
        final m = RegExp(r"\{[\s\S]*?\}", multiLine: true).firstMatch(raw);
        if (m != null) { try { decoded = jsonDecode(m.group(0)!); } catch (_) {} }
      }
      if (decoded is Map<String, dynamic>) {
        await _setLastStatus('gemini', model: model, len: raw.length);
        await _setLastError('');
        return decoded;
      }
      await _setLastStatus('error', model: model, len: 0);
      await _setLastError('parse_error');
      return null;
    } on TimeoutException catch (e) {
      await _setLastStatus('error', model: model, len: 0);
      await _setLastError('timeout:${e.message ?? ''}');
      return null;
    } catch (e) {
      await _setLastStatus('error', model: model, len: 0);
      await _setLastError('exception:${e.toString()}');
      return null;
    }
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

  Future<String> generateChallenge({required List<String> roles, required String locale, int timeoutMs = 6000}) async {
    final r = roles.join(', ');
    final t = {
      'tr': 'Bu koridor/rol dizilimi için en etkili kahramanı seç: $r. Karşılaşma dinamiklerini ve takım uyumunu dikkate al.',
      'en': 'Pick the most effective hero for roles: $r. Consider matchup dynamics and team synergy.',
      'ru': 'Выбери наиболее эффективного героя для ролей: $r. Учитывай матчап и синергию команды.',
      'id': 'Pilih hero paling efektif untuk peran: $r. Pertimbangkan matchup dan sinergi tim.',
      'fil': 'Piliin ang pinaka-epektibong hero para sa mga role: $r. Isaalang-alang ang matchup at team synergy.',
    }[locale] ?? 'Pick the most effective hero for roles: $r.';
    return t;
  }

  Future<Map<String, dynamic>?> analyzeDraftPower({
    required Map<String, dynamic> input,
    required String locale,
    int timeoutMs = 25000,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await _setLastStatus('error', model: '', len: 0);
      await _setLastError('no_api_key');
      return null;
    }
    final models = [
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ];
    final startMs = DateTime.now().millisecondsSinceEpoch;
    String raw = '';
    for (final m in models) {
      try {
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        final remaining = timeoutMs - elapsed;
        if (remaining <= 500) break;
        final gm = GenerativeModel(
          model: m,
          apiKey: apiKey,
          generationConfig: GenerationConfig(temperature: 0.2, topP: 0.95, maxOutputTokens: 1024),
          safetySettings: [
            SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
            SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
          ],
        );
        final jsonStr = jsonEncode(input);
        final prompt = StringBuffer()
          ..writeln("Rolün: Mobile Legends: Bang Bang uzmanı bir ‘Draft Analiz Koçu’.")
          ..writeln("Sadece geçerli JSON döndür. Metinler ${locale.toUpperCase()} dilinde olacak.")
          ..writeln("Girdi JSON:")
          ..writeln(jsonStr)
          ..writeln("Çıktı yapısı tam olarak şu alanları içermeli:")
          ..writeln("{\n  \"draftPower\": { \"ally\": 0-100, \"enemy\": 0-100 },\n  \"draftAdvantageText\": string,\n  \"powerCurve\": { \"early\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"mid\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"late\": { \"ally\": 0-100, \"enemy\": 0-100 } },\n  \"laneComparison\": { \"EXP\": { \"allyScore\": 0-100, \"enemyScore\": 0-100, \"summary\": string }, \"Mid\": {\"allyScore\": 0-100, \"enemyScore\": 0-100, \"summary\": string }, \"Gold\": {\"allyScore\": 0-100, \"enemyScore\": 0-100, \"summary\": string }, \"Jungle\": {\"allyScore\": 0-100, \"enemyScore\": 0-100, \"summary\": string }, \"Roam\": {\"allyScore\": 0-100, \"enemyScore\": 0-100, \"summary\": string } },\n  \"teamSynergy\": { \"cc\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"burst\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"sustain\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"frontline\": { \"ally\": 0-100, \"enemy\": 0-100 }, \"objective\": { \"ally\": 0-100, \"enemy\": 0-100 } },\n  \"metaFit\": { \"ally\": { \"early\": 0-100, \"mid\": 0-100, \"late\": 0-100 }, \"enemy\": { \"early\": 0-100, \"mid\": 0-100, \"late\": 0-100 }, \"summary\": string },\n  \"compositionComparison\": { \"allyAdvantages\": [string], \"enemyAdvantages\": [string], \"summary\": string },\n  \"draftWinner\": \"Ally\"|\"Enemy\",\n  \"draftWinnerReason\": string,\n  \"gamePlan\": { \"early\": string, \"mid\": string, \"late\": string }\n}")
          ..writeln("Kurallar: JSON dışında açıklama yazma. Sayısal değerler 0–100 aralığında ve mantıklı oranlarda olsun.");
        final res = await gm.generateContent([Content.text(prompt.toString())]).timeout(Duration(milliseconds: remaining));
        String out = '';
        if (res.candidates.isNotEmpty) {
          final parts = res.candidates.first.content.parts;
          final texts = <String>[];
          for (final p in parts) { if (p is TextPart) { final t = p.text; if (t.isNotEmpty) texts.add(t); } }
          out = texts.join('\n');
          if (out.isEmpty) { final t = res.text; if (t != null && t.isNotEmpty) out = t; }
        } else {
          out = res.text ?? '';
        }
        raw = out;
        if (raw.isNotEmpty) break;
      } on TimeoutException catch (e) {
        await _setLastStatus('error', model: '', len: 0);
        await _setLastError('timeout:${e.message ?? ''}');
      } catch (e) {
        await _setLastStatus('error', model: '', len: 0);
        await _setLastError('exception:${e.toString()}');
      }
    }
    if (raw.isEmpty) return null;
    String candidate = raw.trim();
    final i = candidate.indexOf('{');
    final j = candidate.lastIndexOf('}');
    if (i >= 0 && j > i) { candidate = candidate.substring(i, j + 1); }
    try {
      final m = jsonDecode(candidate);
      return Map<String, dynamic>.from(m as Map);
    } catch (_) {
      await _setLastStatus('error', model: '', len: 0);
      await _setLastError('parse_error');
      return null;
    }
  }
}
