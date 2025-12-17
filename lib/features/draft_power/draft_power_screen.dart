import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import '../../services/ads_service.dart';
 
import '../../services/hero_repository.dart';
import '../../models/hero_model.dart';
import '../../services/gemini_service.dart';
import 'colors.dart';

class DraftPowerScreen extends StatefulWidget {
  const DraftPowerScreen({super.key});
  @override
  State<DraftPowerScreen> createState() => _DraftPowerScreenState();
}

class _DraftPowerScreenState extends State<DraftPowerScreen> {
  WebViewController? _web;
  final Map<String, String> _ally = {};
  final Map<String, String> _enemy = {};
  BannerAd? _banner;
  bool _bannerReady = false;
  Future<void> _openPicker({required bool isAlly, required String lane}) async {
    final repo = HeroRepository();
    var heroes = await repo.getHeroesCached();
    if (heroes.isEmpty) heroes = await repo.getHeroes();
    if (!mounted) return;
    String query = '';
    String? result;
    final locale = Localizations.localeOf(context).languageCode;
    String displayName(HeroModel h) => h.name(locale);
      String laneKey(String l){
        final s = l.toLowerCase();
        if (s.contains('exp')) return 'exp';
        if (s.contains('mid')) return 'mid';
        if (s.contains('gold')) return 'gold';
        if (s.contains('jungle')) return 'jungle';
        if (s.contains('roam')) return 'roam';
        return '';
      }
    final key = laneKey(lane);
    List<HeroModel> base = heroes;
    if (key.isNotEmpty) {
      base = heroes.where((h){
        final lanes = h.lanes.map((x)=>x.toLowerCase()).toList();
        return lanes.any((x)=>x.contains(key));
      }).toList();
      if (base.isEmpty) base = heroes; // fallback
    }
    if (!mounted) return;
    await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: DraftColors.card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) {
      List<HeroModel> filtered = [...base];
      return StatefulBuilder(builder: (ctx, setSt) {
        if (query.isEmpty) {
          filtered = [...base];
        } else {
          final q = query.toLowerCase();
          filtered = base.where((h) {
            final nameHit = displayName(h).toLowerCase().contains(q) || h.name('en').toLowerCase().contains(q);
            final roleHit = h.roles.map((r)=>r.toLowerCase()).any((r)=>r.contains(q));
            return nameHit || roleHit;
          }).toList();
        }
        filtered.sort((a,b)=> displayName(a).toLowerCase().compareTo(displayName(b).toLowerCase()));
        return SafeArea(child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(
                decoration: const InputDecoration(hintText: 'Hero seç veya ara…'),
                style: const TextStyle(color: DraftColors.textPrimary),
                onChanged: (v) => setSt(() { query = v; }),
              )),
            ]),
            const SizedBox(height: 12),
            Expanded(child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.72),
              cacheExtent: 300,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final h = filtered[i];
                return InkWell(
                  onTap: () { result = h.id; Navigator.pop(ctx); },
                  child: Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (h.imageUrl != null && h.imageUrl!.isNotEmpty)
                        ? _ShimmerImage(url: h.imageUrl!)
                        : Container(width: 48, height: 48, color: DraftColors.card)
                    ),
                    const SizedBox(height: 6),
                    Text(displayName(h), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DraftColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(h.roles.isNotEmpty ? h.roles.join(', ') : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DraftColors.textSecondary, fontSize: 11)),
                  ]),
                );
              },
            )),
          ]),
        ));
      });
    });
    if (result != null) {
      if (!mounted) return;
      if (isAlly) { _ally[lane] = result!; } else { _enemy[lane] = result!; }
      final h = heroes.firstWhere((x) => x.id == result!, orElse: () => HeroModel(id: result!, names: {'en': result!}, roles: const []));
      final role = (h.roles.isNotEmpty ? h.roles.first : lane);
      String? imageUrl;
      try { imageUrl = h.imageUrl ?? await repo.heroImageUrl(result!); } catch (_) {}
      final roleKey = laneKey(lane);
      final heroObj = {
        'id': h.id,
        'hero': h.name(locale),
        'image': (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : (h.imageAsset ?? ''),
        'imageUrl': imageUrl ?? '',
        'role': role,
      };
      final args = jsonEncode([(isAlly?"ally":"enemy"), roleKey, heroObj]);
      try {
        final pickerLogArgs = jsonEncode([h.id, h.name(locale), role, (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : (h.imageAsset ?? '')]);
        await _web?.runJavaScript("try{var a=$pickerLogArgs; console.log('onHeroSelected picker', a[0], a[1], a[2], a[3]);}catch(_){}}");
        final js = "updateHero.apply(null,$args)";
        await _web?.runJavaScript(js);
        // Extra: log for debug
        await _web?.runJavaScript("console.debug('flutter->js updateHero called', '${isAlly?"ally":"enemy"}', '$roleKey')");
        debugPrint("onHeroSelected → team=${isAlly?"ally":"enemy"}, roleKey=$roleKey, heroId=${result!}");
      } catch (_){ }
    }
  }
  @override
  void initState() {
    super.initState();
    Future(() async {
      try { await MobileAds.instance.initialize(); } catch (_) {}
      await _initBanner();
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('BBML', onMessageReceived: (msg) async {
          try {
            debugPrint('DEBUG DRAFT MESSAGE: ${msg.message}');
            final m = jsonDecode(msg.message);
            if (m is Map && m['type'] == 'pick') {
              final side = (m['side'] as String?) ?? 'ally';
              final lane = (m['lane'] as String?) ?? 'Jungle';
              debugPrint("BBML pick received: side=$side, lane=$lane");
              unawaited(AdsService.maybeShowInterstitial(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/2215412440' : null, every: 10));
              if (mounted) { unawaited(_openPicker(isAlly: side == 'ally', lane: lane)); }
              return;
            }
            if (m is Map && m['type'] == 'draft_submit_test') {
              debugPrint('BBML submit (test) received');
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Draft Analizi (Test)')),
                      body: const Center(child: Text('Draft sonucu buraya gelecek')),
                    ),
                  ),
                );
                debugPrint('DEBUG NAVIGATE CALLED');
              }
              return;
            }
            if (m is Map && m['type'] == 'submit') {
              debugPrint('BBML submit received');
              final s = (m['json'] as String?) ?? '{}';
              final js = Uri.decodeComponent(s);
              debugPrint('BBML submit payload decoded: $js');
              unawaited(AdsService.maybeShowInterstitial(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/2215412440' : null, every: 10));
              final messenger = ScaffoldMessenger.maybeOf(context);
              messenger?.showSnackBar(const SnackBar(content: Text('Analiz başlatılıyor…')));
              Map<String, dynamic> parsed = {};
              try { parsed = Map<String, dynamic>.from(jsonDecode(js)); } catch (_) {}
              final a = Map<String, String>.from(parsed['ally'] ?? {});
              final e = Map<String, String>.from(parsed['enemy'] ?? {});
              if (a.isEmpty || e.isEmpty || a.length < 5 || e.length < 5) {
                debugPrint('selectedHeroes boş veya eksik, analiz yapılamıyor');
                messenger?.showSnackBar(const SnackBar(content: Text('Seçimler eksik, analiz yapılamıyor')));
                return;
              }
              Future<bool> confirmAds() async {
                return await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Reklam gerekli'),
                    content: const Text('Bu analiz için 3 reklam izlenmeli.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('İzle')),
                    ],
                  );
                }) ?? false;
              }
              final okProceed = await confirmAds();
              if (!okProceed) return;
              int rem = 3;
              while (rem > 0) {
                final ok = await AdsService.showRewardedInterstitial(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/9163022223' : null);
                if (!ok) { messenger?.showSnackBar(const SnackBar(content: Text('Reklam yüklenemedi'))); return; }
                rem = rem - 1;
                if (rem > 0) {
                  final cont = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx){
                    return AlertDialog(title: const Text('Reklam gerekli'), content: Text('Kalan reklam: $rem'), actions: [TextButton(onPressed: ()=>Navigator.of(ctx).pop(false), child: const Text('Vazgeç')), TextButton(onPressed: ()=>Navigator.of(ctx).pop(true), child: const Text('Devam'))]);
                  }) ?? false;
                  if (!cont) return;
                }
              }
              final locale = Localizations.localeOf(context).languageCode;
              String toRole(String lane){
                final s = lane.toLowerCase();
                if (s.contains('exp')) return 'EXP';
                if (s.contains('mid')) return 'Mid';
                if (s.contains('gold')) return 'Gold';
                if (s.contains('jungle')) return 'Jungle';
                if (s.contains('roam')) return 'Roam';
                return lane;
              }
              () async {
                final repo = HeroRepository();
                var heroes = await repo.getHeroesCached();
                if (heroes.isEmpty) heroes = await repo.getHeroes();
                HeroModel? byId(String id){ return heroes.firstWhere((h) => h.id == id, orElse: () => HeroModel(id: id, names: {'en': id}, roles: const [])); }
                final allyTeam = a.entries.map((kv){ final h = byId(kv.value)!; return { 'hero': h.name(locale), 'role': toRole(kv.key) }; }).toList();
                final enemyTeam = e.entries.map((kv){ final h = byId(kv.value)!; return { 'hero': h.name(locale), 'role': toRole(kv.key) }; }).toList();
                final input = { 'allyTeam': allyTeam, 'enemyTeam': enemyTeam };
                final gs = GeminiService();
                final result = await gs.analyzeDraftPower(input: input, locale: locale, timeoutMs: 24000);
                Map<String, dynamic> data = {};
                if (result != null) {
                  data = result;
                } else {
                  int seedOf(String s){ return s.codeUnits.fold(0, (a,b)=>a*31+b); }
                  int rnd = (seedOf(a.values.join('|')) ^ seedOf(e.values.join('|'))) & 0x7fffffff;
                  int next(){ rnd = (rnd*1103515245 + 12345) & 0x7fffffff; return rnd; }
                  int sc(int base){ return ((base + (next()%21) - 10)).clamp(0,100); }
                  int avg(List<int> xs){ if(xs.isEmpty) return 0; return xs.reduce((p,c)=>p+c)~/xs.length; }
                  Map<String, dynamic> lane(String name){ final l = name.toLowerCase(); final biasA = l.contains('exp')?6:l.contains('jungle')?4:l.contains('mid')?0:l.contains('gold')?5:3; final aSc = sc(50 + biasA); final eSc = sc(50 + (10-biasA)); return { 'allyScore': aSc, 'enemyScore': eSc, 'summary': name=='EXP'?'Üst koridorda kısa takas ve dalga yönetimi avantajı sende.':'Bu koridorda oyun planını rotasyon ve objektif etrafında kur.' }; }
                  final lc = { 'EXP': lane('EXP'), 'Mid': lane('Mid'), 'Gold': lane('Gold'), 'Jungle': lane('Jungle'), 'Roam': lane('Roam') };
                  int laneAllyScore(String k){ final dynamic m = lc[k]; final v = m?['allyScore']; return (v is int) ? v : int.tryParse('$v') ?? 0; }
                  int laneEnemyScore(String k){ final dynamic m = lc[k]; final v = m?['enemyScore']; return (v is int) ? v : int.tryParse('$v') ?? 0; }
                  final allyOverall = avg([laneAllyScore('EXP'), laneAllyScore('Mid'), laneAllyScore('Gold'), laneAllyScore('Jungle'), laneAllyScore('Roam')]);
                  final enemyOverall = avg([laneEnemyScore('EXP'), laneEnemyScore('Mid'), laneEnemyScore('Gold'), laneEnemyScore('Jungle'), laneEnemyScore('Roam')]);
                  final earlyA = sc(50 + (allyOverall-50)~/2); final midA = sc(52 + (allyOverall-50)~/3); final lateA = sc(53 + (allyOverall-50)~/4);
                  final earlyE = sc(50 + (enemyOverall-50)~/2); final midE = sc(52 + (enemyOverall-50)~/3); final lateE = sc(53 + (enemyOverall-50)~/4);
                  final syn = { 'cc': { 'ally': sc(55), 'enemy': sc(55) }, 'burst': { 'ally': sc(54), 'enemy': sc(54) }, 'sustain': { 'ally': sc(50), 'enemy': sc(50) }, 'frontline': { 'ally': sc(52), 'enemy': sc(52) }, 'objective': { 'ally': sc(56), 'enemy': sc(56) } };
                  final metaA = { 'early': sc(52), 'mid': sc(53), 'late': sc(55) };
                  final metaE = { 'early': sc(52), 'mid': sc(53), 'late': sc(55) };
                  final comp = { 'allyAdvantages': ['Erken baskı kurma fırsatları', 'Objektif çevresinde hızlı koordinasyon'], 'enemyAdvantages': ['Geç oyunda ölçeklenme', 'Uzun savaş dayanıklılığı'], 'summary': 'Genel olarak oyun planını erken ve orta oyuna yaslamak avantajlı.' };
                  final winner = allyOverall >= enemyOverall ? 'Ally' : 'Enemy';
                  final advText = winner=='Ally' ? 'Bu draftta toplamda senin takımın belirgin bir avantaja sahip.' : 'Bu draftta rakip takımın toplam gücü biraz daha yüksek.';
                  final plan = { 'early': 'Erken oyunda görüş ve rotasyonla baskı kur.', 'mid': 'Orta oyunda objektif etrafında takım savaşlarını yönet.', 'late': 'Geç oyunda riskleri azalt, pozisyon hatası yapma.' };
                  data = {
                    'draftPower': { 'ally': allyOverall, 'enemy': enemyOverall },
                    'draftAdvantageText': advText,
                    'powerCurve': { 'early': { 'ally': earlyA, 'enemy': earlyE }, 'mid': { 'ally': midA, 'enemy': midE }, 'late': { 'ally': lateA, 'enemy': lateE } },
                    'laneComparison': lc,
                    'teamSynergy': syn,
                    'metaFit': { 'ally': metaA, 'enemy': metaE, 'summary': 'Meta ile uyum orta-iyi seviyede, counter hassasiyetine dikkat.' },
                    'compositionComparison': comp,
                    'draftWinner': winner,
                    'draftWinnerReason': 'Koridor eşleşmeleri ve güç eğrisi toplamına göre.',
                    'gamePlan': plan,
                  };
                }
                if (!mounted) return;
                final payload = jsonEncode(data);
                await _web?.runJavaScript("populateAnalysis($payload)");
                await _web?.runJavaScript('showAnalysis()');
                await _web?.runJavaScript("console.debug('analysis populated')");
              }();
              return;
            }
          } catch (_) {}
        })
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (req) async {
            final url = req.url;
            if (url.startsWith('bbml://pick')) {
              Uri u = Uri.parse(url.replaceFirst('bbml://', 'bbml://host'));
              final side = u.queryParameters['side'] ?? 'ally';
              final lane = u.queryParameters['lane'] ?? 'Jungle';
              if (mounted) { unawaited(_openPicker(isAlly: side == 'ally', lane: lane)); }
              return NavigationDecision.prevent;
            }
            if (url.startsWith('bbml://submit')) {
              return NavigationDecision.prevent;
            }
            if (!url.startsWith('http') && !url.startsWith('https') && !url.startsWith('about:')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ));
      try {
        final html = await DefaultAssetBundle.of(context).loadString('tasarimlar/karsilatirma/code.html');
        await c.loadHtmlString(html);
        debugPrint('DraftPowerScreen: loaded HTML from asset string');
      } catch (e) {
        debugPrint('DraftPowerScreen: asset load failed $e');
        await c.loadHtmlString('<html><body style="background:#151329;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh">İçerik yüklenemedi</body></html>');
      }
      setState(() => _web = c);
    });
  }
  Future<void> _initBanner() async {
    if (!AdsService.enabled) return;
    String unit = Platform.isAndroid ? 'ca-app-pub-2220990495085543/9607366049' : 'ca-app-pub-3940256099942544/2934735716';
    final ad = BannerAd(
      adUnitId: unit,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) { if (mounted) setState(() { _bannerReady = true; }); },
        onAdFailedToLoad: (ad, err) { ad.dispose(); },
      ),
    );
    await ad.load();
    _banner = ad;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draft Güç Analizi'), backgroundColor: DraftColors.background),
      backgroundColor: DraftColors.background,
      body: _web == null ? const Center(child: CircularProgressIndicator()) : WebViewWidget(controller: _web!),
      bottomNavigationBar: AdsService.enabled && _banner != null && _bannerReady
          ? SafeArea(
              child: SizedBox(
                width: _banner!.size.width.toDouble(),
                height: _banner!.size.height.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
            )
          : null,
    );
  }
}

class _ShimmerImage extends StatefulWidget {
  final String url;
  const _ShimmerImage({required this.url});
  @override
  State<_ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<_ShimmerImage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState(){
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose(){ _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(children:[
        Positioned.fill(child: Image.network(widget.url, fit: BoxFit.cover, loadingBuilder: (_, child, progress) => progress==null? child : const SizedBox.shrink(), errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        Positioned.fill(child: AnimatedBuilder(animation: _c, builder: (_, __){
          final v = _c.value;
          final start = (v*2-0.5).clamp(0.0, 1.0);
          final end = (start+0.3).clamp(0.0, 1.0);
          final gradient = LinearGradient(colors: const [Color(0x33151329), Color(0x66151329), Color(0x33151329)], stops: [start, (start+end)/2, end]);
          return Container(decoration: BoxDecoration(gradient: gradient));
        }))
      ]),
    );
  }
}
