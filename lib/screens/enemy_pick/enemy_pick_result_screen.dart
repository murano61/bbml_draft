import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../widgets/primary_button.dart';
import '../../models/hero_model.dart';
import '../../services/hero_repository.dart';
import '../../services/gemini_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/ai_suggestion_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class EnemyPickResultScreen extends StatefulWidget {
  const EnemyPickResultScreen({super.key});

  @override
  State<EnemyPickResultScreen> createState() => _EnemyPickResultScreenState();
}

  class _EnemyPickResultScreenState extends State<EnemyPickResultScreen> {
    final repo = HeroRepository();
    List<HeroModel> _heroes = [];
    List<(HeroModel,String)> _suggestionsCounters = [];
    List<(HeroModel,String)> _suggestionsCountered = [];
    bool _loading = true;
    int _tabIndex = 0;
    bool _aiMode = false;
    List<AiSuggestionEntry> _aiEntries = [];
    String? _html;
  WebViewController? _web;
  int _variation = 0;
  final Set<String> _excludeIds = {};
  Map<String, dynamic>? _lastStatus;
  String? _enemyId;
  double _progress = 0;
  Timer? _progressTimer;
  int _progressStartMs = 0;
  final int _progressTargetMs = 25000;
  BannerAd? _banner;
  bool _bannerReady = false;
  void _ensureThree(List<String> roles, String locale) {
    if (_suggestionsCounters.length >= 3) return;
    final picked = _suggestionsCounters.map((e) => e.$1.id).toSet();
    final roleSet = roles.map((r) => r.toLowerCase()).toSet();
    final laneKeywords = {'gold', 'exp', 'jungle', 'mid', 'roam'};
    final selectedLanes = roleSet.intersection(laneKeywords);
    final pool = roleSet.isNotEmpty
        ? (selectedLanes.isNotEmpty
            ? _heroes.where((h) => h.lanes.map((x) => x.toLowerCase()).toSet().intersection(selectedLanes).isNotEmpty).toList()
            : _heroes.where((h) => h.roles.map((x) => x.toLowerCase()).toSet().intersection(roleSet).isNotEmpty).toList())
        : [..._heroes];
    for (final h in pool) {
      if (_suggestionsCounters.length >= 3) break;
      if (picked.contains(h.id)) continue;
      if (_excludeIds.contains(h.id)) continue;
      if (_enemyId != null && h.id.toLowerCase() == _enemyId!.toLowerCase()) continue;
      _suggestionsCounters.add((h, 'Orta|${'generic_reason'.tr()}'));
      _excludeIds.add(h.id);
    }
  }
  String _replaceNthBackgroundUrl(String html, int n, String? url) {
    if (url == null || url.isEmpty) return html;
    final rx = RegExp(r'background-image:\s*url\(".*?"\)');
    var i = 0;
    return html.replaceAllMapped(rx, (m) {
      i++;
      if (i == n) {
        return 'background-image: url("$url")';
      }
      return m.group(0)!;
    });
  }

  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load({bool noCache = false}) async {
    setState(() { _loading = true; _progress = 0; });
    _startProgress();
    final route = ModalRoute.of(context);
    final args = (route?.settings.arguments) as Map<String, dynamic>?;
    final enemyId = args?['enemyHeroId'] as String?;
    _enemyId = enemyId;
    final roles = List<String>.from((args?['role'] ?? const []) as List);
    _aiMode = (args?['ai'] == true);
    final locale = Localizations.localeOf(context).languageCode;
    _heroes = await repo.getHeroesCached();
    if (_heroes.isEmpty) { _heroes = await repo.getHeroes(); }
    if (!_aiMode && enemyId != null && enemyId.isNotEmpty) {
      final counters = await repo.countersFor(enemyId, locale);
      if (counters != null) {
        final listCounters = counters.counters.take(5).map((c) {
          final h = _heroes.firstWhere((e) => e.id == c.heroId, orElse: () => HeroModel(id: c.heroId, names: {'en': c.heroId}, roles: const []));
          final reason = c.reason[locale] ?? c.reason['en'] ?? '';
          final diff = c.difficulty.toLowerCase();
          final label = diff == 'easy' || diff == 'kolay' ? 'Kolay' : diff == 'hard' || diff == 'zor' ? 'Zor' : 'Orta';
          return (h, '$label|$reason');
        }).toList();
        final listCountered = counters.countered.take(5).map((c) {
          final h = _heroes.firstWhere((e) => e.id == c.heroId, orElse: () => HeroModel(id: c.heroId, names: {'en': c.heroId}, roles: const []));
          final reason = c.reason[locale] ?? c.reason['en'] ?? '';
          final diff = c.difficulty.toLowerCase();
          final label = diff == 'easy' || diff == 'kolay' ? 'Kolay' : diff == 'hard' || diff == 'zor' ? 'Zor' : 'Orta';
          return (h, '$label|$reason');
        }).toList();
        _suggestionsCounters = listCounters;
        _suggestionsCountered = listCountered;
      }
    }
    if (_aiMode) {
      if (enemyId == null || enemyId.isEmpty) {
        final gs = GeminiService();
        _aiEntries = await gs.suggest(enemyHeroId: null, roles: roles, locale: locale, noCache: true, nonce: 'v$_variation', excludeHeroIds: const [], timeoutMs: 20000, requireGemini: true);
        final challenge = await gs.generateChallenge(roles: roles, locale: locale, timeoutMs: 6000);
        try { _lastStatus = await gs.getLastStatus(); } catch (_) {}
        if (_aiEntries.isNotEmpty) {
          _suggestionsCounters = _aiEntries.map((e) {
            final h = _heroes.firstWhere((x) => x.id == e.heroId, orElse: () => HeroModel(id: e.heroId, names: {'en': e.heroId}, roles: const []));
            _excludeIds.add(h.id);
            return (h, 'Orta|${e.reason}');
          }).toList();
        }
        _ensureThree(roles, locale);
        if (_suggestionsCounters.isEmpty) {
          final roleSet = roles.map((r) => r.toLowerCase()).toSet();
          final laneKeywords = {'gold', 'exp', 'jungle', 'mid', 'roam'};
          final selectedLanes = roleSet.intersection(laneKeywords);
          List<HeroModel> pool = roleSet.isNotEmpty
              ? (selectedLanes.isNotEmpty
                  ? _heroes.where((h) => h.lanes.map((x) => x.toLowerCase()).toSet().intersection(selectedLanes).isNotEmpty).toList()
                  : _heroes.where((h) => h.roles.map((x) => x.toLowerCase()).toSet().intersection(roleSet).isNotEmpty).toList())
              : [..._heroes];
          if (pool.length < 3) pool = [..._heroes];
          pool.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
          final bestH = pool.isNotEmpty ? pool[0] : null;
          final alt2H = pool.length > 1 ? pool[1] : null;
          final alt3H = pool.length > 2 ? pool[2] : null;
          if (bestH != null) _suggestionsCounters.add((bestH, 'Orta|${bestH.roles.isNotEmpty ? bestH.roles.first : ''}'));
          if (alt2H != null) _suggestionsCounters.add((alt2H, 'Orta|'));
          if (alt3H != null) _suggestionsCounters.add((alt3H, 'Orta|'));
        }
        try {
          final tpl = await rootBundle.loadString('tasarimlar/direkt_öneri/code.html');
          String html = tpl;
          final best = _suggestionsCounters.isNotEmpty ? _suggestionsCounters[0].$1 : null;
          final bestReason = _suggestionsCounters.isNotEmpty ? (_suggestionsCounters[0].$2.split('|').length > 1 ? _suggestionsCounters[0].$2.split('|')[1] : '') : '';
          final alt2 = _suggestionsCounters.length > 1 ? _suggestionsCounters[1].$1 : null;
          final alt3 = _suggestionsCounters.length > 2 ? _suggestionsCounters[2].$1 : null;
          final alt2Reason = _suggestionsCounters.length > 1 ? (_suggestionsCounters[1].$2.split('|').length > 1 ? _suggestionsCounters[1].$2.split('|')[1] : '') : '';
          final alt3Reason = _suggestionsCounters.length > 2 ? (_suggestionsCounters[2].$2.split('|').length > 1 ? _suggestionsCounters[2].$2.split('|')[1] : '') : '';
          final localeCode = locale;
          if (best != null) {
            final role = best.roles.isNotEmpty ? best.roles.first : 'Hero';
            html = html.replaceFirst('Layla', best.name(localeCode));
            html = html.replaceFirst('Marksman', role);
            if (bestReason.isNotEmpty) {
              html = html.replaceFirst('Bu maç seni taşıtabilir', bestReason);
            }
          }
          if (alt2 != null) { html = html.replaceFirst('Tigreal', alt2.name(localeCode)); }
          if (alt3 != null) { html = html.replaceFirst('Eudora', alt3.name(localeCode)); }
          final bestUrl = best != null ? await repo.heroImageUrl(best.id) : null;
          final alt2Url = alt2 != null ? await repo.heroImageUrl(alt2.id) : null;
          final alt3Url = alt3 != null ? await repo.heroImageUrl(alt3.id) : null;
          if (bestUrl != null && bestUrl.isNotEmpty) html = _replaceNthBackgroundUrl(html, 1, bestUrl);
          if (alt2Url != null && alt2Url.isNotEmpty) html = _replaceNthBackgroundUrl(html, 2, alt2Url);
          if (alt3Url != null && alt3Url.isNotEmpty) html = _replaceNthBackgroundUrl(html, 3, alt3Url);
          _html = html;
          _web = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(NavigationDelegate(
              onNavigationRequest: (req) {
                final url = req.url;
                if (url.startsWith('bbml://')) {
                  if (url.contains('ask_new')) {
                    _variation++;
                    setState(() => _loading = true);
                    _load(noCache: true);
                  } else if (url.contains('picked')) {
                    Navigator.pushNamedAndRemoveUntil(context, K.routeHome, (r) => false);
                  } else if (url.contains('back')) {
                    Navigator.pop(context);
                  }
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageFinished: (url) async {
                final safeChallenge = challenge.replaceAll("'", "\\'");
                final bestName = best?.name(localeCode) ?? '';
                final bestRole = best != null && best.roles.isNotEmpty ? best.roles.first : '';
                String bestReasonText = bestReason;
                if (bestReasonText.trim().isEmpty || bestReasonText.trim().toLowerCase() == 'generic_reason') {
                  bestReasonText = localeCode == 'tr' ? 'Bu kahramanın yetenek seti orta koridorda etkilidir.' : 'This hero\'s kit is effective in mid lane.';
                }
                final alt2Name = alt2?.name(localeCode) ?? '';
                final alt3Name = alt3?.name(localeCode) ?? '';
                final jsBestName = bestName.replaceAll("'", "\\'");
                final jsBestRole = bestRole.replaceAll("'", "\\'");
                final jsBestReason = bestReasonText.replaceAll("'", "\\'");
                final jsAlt2 = alt2Name.replaceAll("'", "\\'");
                final jsAlt3 = alt3Name.replaceAll("'", "\\'");
                final jsAlt2Desc = (alt2Reason.isNotEmpty ? alt2Reason : (localeCode=='tr' ? 'Güvenli oyun isteyenlere.' : 'For safe playstyle.')).replaceAll("'", "\\'");
                final jsAlt3Desc = (alt3Reason.isNotEmpty ? alt3Reason : (localeCode=='tr' ? 'Agresif tarz sevenlere.' : 'For aggressive players.')).replaceAll("'", "\\'");
                final jsBestUrl = (bestUrl ?? '').replaceAll("'", "\\'");
                final jsAlt2Url = (alt2Url ?? '').replaceAll("'", "\\'");
                final jsAlt3Url = (alt3Url ?? '').replaceAll("'", "\\'");
                await _web!.runJavaScript("""
                  (function(){
                    setTimeout(()=>{
                    const btns = Array.from(document.querySelectorAll('button, a'));
                    btns.forEach(b=>{
                      const t = (b.innerText||'').trim().toLowerCase();
                      if(t.includes('yeni öneri ver') || t.includes('ai reroll') || t.includes('get different suggestions')){
                        b.addEventListener('click', ()=>{ window.location.href='bbml://ask_new'; });
                      }
                      if(t.includes('bu kahramanı kullan') || t.includes("i've picked this hero")){
                        b.addEventListener('click', ()=>{ window.location.href='bbml://picked'; });
                      }
                    });
                    const challengeEl = document.getElementById('challenge-text');
                    if (challengeEl) { challengeEl.innerText = '$safeChallenge'; }
                    // IDs for deterministic binding
                    const bestCard = document.getElementById('best-bg');
                    if (bestCard) {
                      const nameEl = document.getElementById('best-name');
                      const roleEl = document.getElementById('best-role');
                      const reasonEl = document.getElementById('best-reason');
                      if (nameEl && '$jsBestName') nameEl.textContent = '$jsBestName';
                      if (roleEl && '$jsBestRole') roleEl.textContent = '$jsBestRole';
                      if (reasonEl && '$jsBestReason') reasonEl.textContent = '$jsBestReason';
                      if ('$jsBestUrl') bestCard.style.backgroundImage = `linear-gradient(0deg, rgba(26, 15, 43, 0.8) 0%, rgba(26, 15, 43, 0) 100%), url('$jsBestUrl')`;
                    }
                    const alt2Bg = document.getElementById('alt2-bg');
                    const alt3Bg = document.getElementById('alt3-bg');
                    const alt2NameEl = document.getElementById('alt2-name');
                    const alt3NameEl = document.getElementById('alt3-name');
                    const alt2DescEl = document.getElementById('alt2-desc');
                    const alt3DescEl = document.getElementById('alt3-desc');
                    if (alt2NameEl && '$jsAlt2') alt2NameEl.textContent = '$jsAlt2';
                    if (alt3NameEl && '$jsAlt3') alt3NameEl.textContent = '$jsAlt3';
                    if (alt2DescEl && '$jsAlt2Desc') alt2DescEl.textContent = '$jsAlt2Desc';
                    if (alt3DescEl && '$jsAlt3Desc') alt3DescEl.textContent = '$jsAlt3Desc';
                    if (alt2Bg && '$jsAlt2Url') alt2Bg.style.backgroundImage = `url('$jsAlt2Url')`;
                    if (alt2Bg) alt2Bg.addEventListener('click', ()=>{ window.location.href='bbml://hero?id=${alt2?.id ?? ''}'; });
                    if (alt3Bg && '$jsAlt3Url') alt3Bg.style.backgroundImage = `url('$jsAlt3Url')`;
                    if (alt3Bg) alt3Bg.addEventListener('click', ()=>{ window.location.href='bbml://hero?id=${alt3?.id ?? ''}'; });
                    }, 50);
                  })();
                """);
              },
            ))
            ..loadHtmlString(_html!);
          _initBanner();
        } catch (_) {}
        _suggestionsCountered = const [];
      } else {
        final gs = GeminiService();
        _excludeIds.add(enemyId);
        _aiEntries = await gs.suggest(enemyHeroId: enemyId, roles: roles, locale: locale, noCache: true, nonce: 'v$_variation', excludeHeroIds: _excludeIds.toList(), timeoutMs: 20000, requireGemini: true);
        try { _lastStatus = await gs.getLastStatus(); } catch (_) {}
        if (_aiEntries.isNotEmpty) {
          _suggestionsCounters = _aiEntries.map((e) {
            final h = _heroes.firstWhere((x) => x.id == e.heroId, orElse: () => HeroModel(id: e.heroId, names: {'en': e.heroId}, roles: const []));
            _excludeIds.add(h.id);
            return (h, 'Orta|${e.reason}');
          }).toList();
          _ensureThree(roles, locale);
          try { await gs.setLastStatusPublic('gemini', model: (_lastStatus?['model']??'') as String? ?? '', len: 0, err: ''); } catch (_) {}
        } else {
          // Gemini zorunlu, fallback yapmıyoruz; hata durumunu üstte göstereceğiz.
        }
        _suggestionsCountered = const [];
        // continue to HTML render for enemy flow below
      }

      if (enemyId != null && enemyId.isNotEmpty) {
        if (_suggestionsCounters.isNotEmpty) {
          try {
            final last = await GeminiService().getLastStatus();
            final src = (last['source'] ?? '') as String;
            if (src == 'gemini' && _aiEntries.isNotEmpty) {
              await AiSuggestionManager().incrementUsed();
            }
            _lastStatus = last;
          } catch (_) {}
        }
      }
      if (_aiMode && (enemyId == null || enemyId.isEmpty) && _aiEntries.isNotEmpty) {
        try {
          await AiSuggestionManager().incrementUsed();
        } catch (_) {}
      }

      if (enemyId != null && enemyId.isNotEmpty) {
        try {
          final tpl = await rootBundle.loadString('tasarımlar/ai sayfası/ai_öneri_sonuç_ekranı/code.html');
          String html = tpl;
          final best = _suggestionsCounters.isNotEmpty ? _suggestionsCounters[0].$1 : null;
          final bestReason = _suggestionsCounters.isNotEmpty ? _suggestionsCounters[0].$2.split('|').length > 1 ? _suggestionsCounters[0].$2.split('|')[1] : '' : '';
          final alt2 = _suggestionsCounters.length > 1 ? _suggestionsCounters[1].$1 : null;
          final alt3 = _suggestionsCounters.length > 2 ? _suggestionsCounters[2].$1 : null;
          final tAi = {
            'tr': 'Yapay Zeka Önerisi',
            'en': 'AI Recommendation',
            'ru': 'Рекомендация ИИ',
            'id': 'Rekomendasi AI',
            'fil': 'AI Rekomendasyon',
          }[locale] ?? 'AI Recommendation';
          final tBest = {
            'tr': 'Senin için en iyi seçim',
            'en': 'Best Pick For You',
            'ru': 'Лучший выбор для вас',
            'id': 'Pilihan Terbaik Untukmu',
            'fil': 'Pinakamainam na Pagpili para sa Iyo',
          }[locale] ?? 'Best Pick For You';
          final tAlt2 = {
            'tr': 'Alternatif 2',
            'en': 'Alternative 2',
            'ru': 'Альтернатива 2',
            'id': 'Alternatif 2',
            'fil': 'Alternatibo 2',
          }[locale] ?? 'Alternative 2';
          final tAlt3 = {
            'tr': 'Alternatif 3',
            'en': 'Alternative 3',
            'ru': 'Альтернатива 3',
            'id': 'Alternatif 3',
            'fil': 'Alternatibo 3',
          }[locale] ?? 'Alternative 3';
          final tWhy = {
            'tr': 'Neden bu kahraman?',
            'en': 'Why this hero?',
            'ru': 'Почему этот герой?',
            'id': 'Mengapa hero ini?',
            'fil': 'Bakit itong hero?',
          }[locale] ?? 'Why this hero?';
          html = html.replaceFirst('AI Recommendation', tAi);
          html = html.replaceFirst('Best Pick For You', tBest);
          html = html.replaceFirst('Alternative 2', tAlt2);
          html = html.replaceFirst('Alternative 3', tAlt3);
          html = html.replaceFirst('Why this hero?', tWhy);
          if (best != null) {
            final role = best.roles.isNotEmpty ? best.roles.first : 'Hero';
            html = html.replaceFirst('Luminara', best.name(locale));
            html = html.replaceFirst('Mage', role);
            if (bestReason.isNotEmpty) {
              html = html.replaceFirst('Her AoE control is perfect against the enemy team\'s dive composition.', bestReason);
            }
          }
          if (alt2 != null) {
            html = html.replaceFirst('Valerius', alt2.name(locale));
          }
          if (alt3 != null) {
            html = html.replaceFirst('Nyx', alt3.name(locale));
          }
          final bestUrl = best != null ? await repo.heroImageUrl(best.id) : null;
          final alt2Url = alt2 != null ? await repo.heroImageUrl(alt2.id) : null;
          final alt3Url = alt3 != null ? await repo.heroImageUrl(alt3.id) : null;
          if (bestUrl != null && bestUrl.isNotEmpty) html = _replaceNthBackgroundUrl(html, 1, bestUrl);
          if (alt2Url != null && alt2Url.isNotEmpty) html = _replaceNthBackgroundUrl(html, 2, alt2Url);
          if (alt3Url != null && alt3Url.isNotEmpty) html = _replaceNthBackgroundUrl(html, 3, alt3Url);
          if (best != null) {
            _html = html;
          } else {
            _html = null;
          }
          _web = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(NavigationDelegate(
              onNavigationRequest: (req) {
                final url = req.url;
                if (url.startsWith('bbml://')) {
                  if (url.contains('ask_new')) {
                    _variation++;
                    setState(() => _loading = true);
                    _load(noCache: true);
                  } else if (url.contains('picked')) {
                    Navigator.pushNamedAndRemoveUntil(context, K.routeHome, (r) => false);
                  } else if (url.contains('back')) {
                    Navigator.pop(context);
                  } else if (url.contains('hero?id=')) {
                  }
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onPageFinished: (url) async {
                final bn = (best?.name(locale) ?? '').replaceAll("'", "\\'");
                final br = (best != null && best.roles.isNotEmpty ? best.roles.first : '').replaceAll("'", "\\'");
                final bu = (bestUrl ?? '').replaceAll("'", "\\'");
                final a2n = (alt2?.name(locale) ?? '').replaceAll("'", "\\'");
                final a3n = (alt3?.name(locale) ?? '').replaceAll("'", "\\'");
                final a2u = (alt2Url ?? '').replaceAll("'", "\\'");
                final a3u = (alt3Url ?? '').replaceAll("'", "\\'");
                await _web!.runJavaScript("""
                  (function(){
                    const btns = Array.from(document.querySelectorAll('button'));
                    btns.forEach(b=>{
                      const t = (b.innerText||'').trim().toLowerCase();
                      if(t.includes('get different suggestions')){
                        b.addEventListener('click', ()=>{ window.location.href='bbml://ask_new'; });
                      }
                      if(t.includes("i've picked this hero")){
                        b.addEventListener('click', ()=>{ window.location.href='bbml://picked'; });
                      }
                    });
                    const backs = Array.from(document.querySelectorAll('.material-symbols-outlined'));
                    if(backs.length>0){ backs[0].addEventListener('click', ()=>{ window.location.href='bbml://back'; }); }
                    // Bind IDs
                    const bbg = document.getElementById('best-bg'); if (bbg && '$bu') bbg.style.backgroundImage = `url('$bu')`;
                    const bnEl = document.getElementById('best-name'); if (bnEl && '$bn') bnEl.textContent = '$bn';
                    const brEl = document.getElementById('best-role'); if (brEl && '$br') brEl.textContent = '$br';
                    // hero profile navigation disabled
                    // hero profile navigation disabled
                    // hero profile navigation disabled
                    const a2bg = document.getElementById('alt2-bg'); if (a2bg && '$a2u') a2bg.style.backgroundImage = `url('$a2u')`;
                    const a3bg = document.getElementById('alt3-bg'); if (a3bg && '$a3u') a3bg.style.backgroundImage = `url('$a3u')`;
                    const a2nEl = document.getElementById('alt2-name'); if (a2nEl && '$a2n') a2nEl.textContent = '$a2n';
                    const a3nEl = document.getElementById('alt3-name'); if (a3nEl && '$a3n') a3nEl.textContent = '$a3n';
                    if (a2bg){
                      a2bg.style.cursor='pointer'; a2bg.style.position='relative';
                      Array.from(a2bg.querySelectorAll('*')).forEach(el=>{ try{ el.style.pointerEvents='none'; }catch{} });
                      const ov2 = document.createElement('a');
                      ov2.setAttribute('href','bbml://hero?id=${alt2?.id ?? ''}');
                      ov2.style.position='absolute'; ov2.style.left='0'; ov2.style.top='0'; ov2.style.right='0'; ov2.style.bottom='0';
                      ov2.style.width='100%'; ov2.style.height='100%'; ov2.style.zIndex='999'; ov2.style.background='rgba(0,0,0,0)'; ov2.style.pointerEvents='auto';
                      a2bg.appendChild(ov2);
                    }
                    if (a3bg){
                      a3bg.style.cursor='pointer'; a3bg.style.position='relative';
                      Array.from(a3bg.querySelectorAll('*')).forEach(el=>{ try{ el.style.pointerEvents='none'; }catch{} });
                      const ov3 = document.createElement('a');
                      ov3.setAttribute('href','bbml://hero?id=${alt3?.id ?? ''}');
                      ov3.style.position='absolute'; ov3.style.left='0'; ov3.style.top='0'; ov3.style.right='0'; ov3.style.bottom='0';
                      ov3.style.width='100%'; ov3.style.height='100%'; ov3.style.zIndex='999'; ov3.style.background='rgba(0,0,0,0)'; ov3.style.pointerEvents='auto';
                      a3bg.appendChild(ov3);
                    }
                    // clickable overlays for alt cards
                    if (a2bg){
                      const ov2 = document.createElement('a'); ov2.setAttribute('href','bbml://hero?id=${alt2?.id ?? ''}');
                      ov2.style.position='absolute'; ov2.style.inset='0'; ov2.style.zIndex='5'; ov2.style.background='transparent';
                      a2bg.style.position='relative'; a2bg.appendChild(ov2);
                    }
                    if (a3bg){
                      const ov3 = document.createElement('a'); ov3.setAttribute('href','bbml://hero?id=${alt3?.id ?? ''}');
                      ov3.style.position='absolute'; ov3.style.inset='0'; ov3.style.zIndex='5'; ov3.style.background='transparent';
                      a3bg.style.position='relative'; a3bg.appendChild(ov3);
                    }
                  })();
                """);
              },
            ))
            ..loadHtmlString(_html!);
          _initBanner();
          
        } catch (_) {}
      }
    }
    if (!mounted) return;
    _stopProgress();
    setState(() => _loading = false);
  }

  Future<void> _initBanner() async {
    final unit = Platform.isAndroid ? 'ca-app-pub-2220990495085543/9607366049' : 'ca-app-pub-3940256099942544/2934735716';
    final ad = BannerAd(
      adUnitId: unit,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) { setState(() { _bannerReady = true; }); },
        onAdFailedToLoad: (ad, err) { ad.dispose(); },
      ),
    );
    await ad.load();
    _banner = ad;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _aiMode ? null : AppBar(title: Text('enemy_pick_title'.tr())),
      body: _loading ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text((){
              final locale = Localizations.localeOf(context).languageCode;
              final msgs = {
                'tr': ['Yapay Zeka en ince ayrıntısına kadar düşünüyor…', 'Yapay Zeka senin için en iyi sonucu düşünüyor…'],
                'en': ['AI is thinking through every detail…', 'AI is finding the best outcome for you…'],
                'ru': ['ИИ продумывает каждую деталь…', 'ИИ ищет лучший результат для вас…'],
                'id': ['AI memikirkan setiap detail…', 'AI mencari hasil terbaik untukmu…'],
                'fil': ['Iniisip ng AI ang bawat detalye…', 'Hinahanap ng AI ang pinakamahusay na resulta para sa iyo…'],
              }[locale] ?? ['AI is thinking through every detail…', 'AI is finding the best outcome for you…'];
              return msgs[_variation % 2];
            }(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            _progressBar(),
          ])) : (_aiMode && _html != null && _web != null)
          ? Stack(children:[
              Positioned.fill(child: WebViewWidget(controller: _web!)),
              if (_lastStatus != null) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text(
                'SRC:${(_lastStatus!['source']??'')}, MODEL:${(_lastStatus!['model']??'')}${((_lastStatus!['err']??'') as String).isNotEmpty ? ', ERR: ${_lastStatus!['err'] as String}' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              )))
            ])
          : _aiMode
                  ? _aiErrorWidget(context)
              : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Benim counterlarım neler?', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Main hero’nu seç, sana karşı güçlü olan kahramanları ve dikkat etmen gereken noktaları gösterelim.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _segButton(label: 'best_counters_title'.tr(), selected: _tabIndex == 0, onTap: () { setState(() { _tabIndex = 0; }); })),
            const SizedBox(width: 8),
            Expanded(child: _segButton(label: 'most_countered_title'.tr(), selected: _tabIndex == 1, onTap: () { setState(() { _tabIndex = 1; }); })),
          ]),
          const SizedBox(height: 12),
          ...List.generate((_tabIndex == 0 ? _suggestionsCounters.length : _suggestionsCountered.length), (i) {
            final (h, info) = _tabIndex == 0 ? _suggestionsCounters[i] : _suggestionsCountered[i];
            final parts = info.split('|');
            final diff = parts.isNotEmpty ? parts[0] : 'Orta';
            final reason = parts.length > 1 ? parts[1] : 'generic_reason'.tr();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _counterCard(context, h, reason, diff),
            );
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.tips_and_updates, color: AppColors.primary), const SizedBox(width: 8), Text('tactics'.tr(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              _bullet(context, 'generic_early'.tr()),
              _bullet(context, 'generic_mid'.tr()),
              _bullet(context, 'generic_late'.tr()),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: PrimaryButton(label: 'ask_new'.tr(), onPressed: () => Navigator.pushReplacementNamed(context, K.routeEnemyPick))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton(label: 'go_home'.tr(), onPressed: () => Navigator.pushNamedAndRemoveUntil(context, K.routeHome, (r) => false))),
          ]),
        ]),
      ),
      bottomNavigationBar: (_aiMode && _banner != null && _bannerReady)
          ? Container(
              height: _banner!.size.height.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _banner!),
            )
          : null,
    );
  }

  void _startProgress() {
    _stopProgress();
    _progressStartMs = DateTime.now().millisecondsSinceEpoch;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return;
      setState(() {
        final elapsed = DateTime.now().millisecondsSinceEpoch - _progressStartMs;
        final ratio = (elapsed / _progressTargetMs).clamp(0.0, 1.0);
        _progress = (ratio * 98.0).clamp(0.0, 98.0);
      });
    });
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    if (mounted) {
      setState(() { _progress = 100; });
    }
  }

  Widget _progressBar() {
    final p = (_progress.clamp(0, 100)) / 100.0;
    return SizedBox(
      width: 260,
      height: 16,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1430),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
          ),
        ),
        FractionallySizedBox(
          widthFactor: p,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary]),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Align(
          alignment: Alignment((p * 2) - 1.0, 0),
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x802BD9FF), blurRadius: 6)]),
          ),
        ),
      ]),
    );
  }


  Widget _aiErrorWidget(BuildContext context) {
    final src = (_lastStatus?['source'] ?? '') as String;
    final model = (_lastStatus?['model'] ?? '') as String;
    final err = (_lastStatus?['err'] ?? '') as String;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 40),
            const SizedBox(height: 12),
            Text('AI servisi yanıt vermedi. Lütfen tekrar deneyin.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (src.isNotEmpty || model.isNotEmpty || err.isNotEmpty)
              Text('SRC:$src, MODEL:$model${err.isNotEmpty ? ', ERR: $err' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(label: 'Tekrar Dene', expanded: false, onPressed: () { setState(() { _loading = true; _variation++; }); _load(noCache: true); }),
                const SizedBox(width: 12),
                PrimaryButton(label: 'Geri Dön', expanded: false, onPressed: () { Navigator.pop(context); }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle, color: Colors.white70, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70))),
    ]);
  }

  Widget _counterCard(BuildContext context, HeroModel hero, String subtitle, String difficulty) {
    Color badgeColor;
    switch (difficulty.toLowerCase()) {
      case 'kolay':
      case 'easy':
        badgeColor = Colors.green;
        break;
      case 'orta':
      case 'medium':
        badgeColor = Colors.yellow;
        break;
      case 'zor':
      case 'hard':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = AppColors.accentPurple;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF271C27), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF543B54))),
      child: Row(children: [
        FutureBuilder<String?>(
          future: repo.heroImageUrl(hero.id),
          builder: (context, snap) {
            final url = snap.data;
            if (url != null && url.isNotEmpty) {
              return CircleAvatar(radius: 22, backgroundColor: AppColors.primary, backgroundImage: NetworkImage(url));
            }
            return CircleAvatar(radius: 22, backgroundColor: AppColors.primary, child: Text(hero.name(Localizations.localeOf(context).languageCode).substring(0,1).toUpperCase(), style: const TextStyle(color: Colors.white)));
          },
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hero.name(Localizations.localeOf(context).languageCode), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ])),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: Text(difficulty, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _segButton({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 40,
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.card, borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
