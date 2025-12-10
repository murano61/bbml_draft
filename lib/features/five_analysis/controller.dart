import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import '../../services/gemini_service.dart';
import 'dart:ui' as ui;
import 'dart:math';

class FiveAnalysisController with ChangeNotifier {
  FiveAnalysisState state = FiveAnalysisState.empty;
  final List<HeroPick> picks = [];
  FiveAnalysisResult? result;

  void reset() {
    state = FiveAnalysisState.empty;
    picks.clear();
    result = null;
    notifyListeners();
  }

  void setPicks(List<HeroPick> list) {
    picks
      ..clear()
      ..addAll(list.take(5));
    state = FiveAnalysisState.loading;
    notifyListeners();
    _analyze();
  }

  Future<void> _analyze() async {
    final service = GeminiService();
    final locale = ui.PlatformDispatcher.instance.locale.languageCode;
    final heroNames = picks.map((e) => e.heroName).toList();
    final lanes = picks.map((e) => e.role.laneLabel.toLowerCase()).toSet().toList();
    Map<String, dynamic>? ai;
    try { ai = await service.analyzeFive(heroes: heroNames, lanes: lanes, locale: locale, timeoutMs: 16000); } catch (_) {}
    Map<MetricTab, List<Metric>> metrics;
    int overall;
    String tierLabel;
    String tierSubtitle;
    List<Badge> badges;
    List<AiSuggestion> aiSugs = const [];
    if (ai != null && ai.isNotEmpty) {
      List<Metric> parseList(String key) {
        final list = ai![key];
        if (list is List) {
          return list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final s = (m['score'] is num) ? (m['score'] as num).round() : int.tryParse('${m['score'] ?? 0}') ?? 0;
            final t = (m['title'] ?? '').toString();
            final d = (m['desc'] ?? m['description'] ?? '').toString();
            return Metric(title: t, score: s.clamp(0, 100), description: d);
          }).toList();
        }
        return const [];
      }
      final g = parseList('genel');
      final s = parseList('strateji');
      final m = parseList('meta & zorluk');
      final mz = m.isNotEmpty ? m : parseList('meta_zorluk');
      metrics = {
        MetricTab.general: g,
        MetricTab.strategy: s,
        MetricTab.metaDifficulty: mz,
      };
      int avg() {
        final all = [...g, ...s, ...mz];
        if (all.isEmpty) return 0;
        return (all.map((e) => e.score).reduce((a, b) => a + b) / all.length).round();
      }
      String tier(int sc) {
        if (sc >= 90) return 'Tier: S';
        if (sc >= 80) return 'Tier: A';
        if (sc >= 70) return 'Tier: B';
        if (sc >= 60) return 'Tier: C';
        return 'Tier: D';
      }
      overall = (ai['overall_score'] is num) ? (ai['overall_score'] as num).round() : int.tryParse('${ai['overall_score'] ?? ''}') ?? avg();
      overall = overall.clamp(0, 100);
      tierLabel = (ai['tier_label'] ?? '').toString();
      if (tierLabel.isEmpty) tierLabel = tier(overall);
      tierSubtitle = (ai['tier_subtitle'] ?? '').toString();
      if (tierSubtitle.isEmpty) tierSubtitle = 'Kompozisyon analizi tamamlandı.';
      badges = const [];
      final allScores = [...g, ...s, ...mz].map((e)=>e.score).toList();
      if (allScores.isNotEmpty) {
        final lowCount = allScores.where((x)=>x<60).length;
        final veryLow = allScores.where((x)=>x<45).length;
        int penalty = 0;
        if (veryLow>0) penalty += 8*veryLow;
        if (lowCount>1) penalty += 4*(lowCount-1);
        overall = (overall - penalty).clamp(0, 100);
        tierLabel = tier(overall);
      }
      final sugsList = ai['suggestions'];
      if (sugsList is List) {
        aiSugs = sugsList.map((e) => AiSuggestion(e.toString())).where((x) => x.text.isNotEmpty).toList();
        if (aiSugs.length > 5) {
          aiSugs = aiSugs.take(5).toList();
        }
      } else {
        aiSugs = const [];
      }
    } else {
      final lanesUsed = picks.map((e) => e.role.laneLabel.toLowerCase()).toSet();
      final hasJungle = lanesUsed.contains('jungle');
      final hasGold = lanesUsed.contains('gold lane') || lanesUsed.contains('gold');
      final hasMid = lanesUsed.contains('mid lane') || lanesUsed.contains('mid');
      final hasExp = lanesUsed.contains('exp lane') || lanesUsed.contains('exp');
      final hasRoam = lanesUsed.contains('roam');
      final seed = (picks.map((e)=>e.heroName).join('|') + lanesUsed.join('|')).hashCode;
      final rng = Random(seed);
      int sc(int v){ return v.clamp(0,100); }

      final g = <Metric>[
        Metric(title: 'Rol Dengesi & Kompozisyon', score: sc(50 + lanesUsed.length*8 - (hasRoam?0:6) - (hasJungle?0:6) + rng.nextInt(7)-3), description: 'Takım rolleri arasındaki denge ve rol dağılımı.'),
        Metric(title: 'Hasar Dağılımı', score: sc(55 + (hasGold?10:0) + (hasMid?8:0) + rng.nextInt(10)-5), description: 'Fiziksel ve büyü hasarı oranlarının uyumu.'),
        Metric(title: 'CC & Peel Potansiyeli', score: sc(48 + (hasRoam?10:0) + rng.nextInt(10)-5), description: 'Kitle kontrol ve taşıyıcı koruma kapasitesi.'),
        Metric(title: 'Dayanıklılık', score: sc(52 + (hasExp?8:0) + rng.nextInt(10)-5), description: 'Ön hatın dayanma gücü ve sürekliliği.'),
        Metric(title: 'Mobilite', score: sc(50 + (hasJungle?6:0) + rng.nextInt(12)-6), description: 'Rotasyon ve harita hareket kabiliyeti.'),
        Metric(title: 'Görüş Kontrolü', score: sc(47 + (hasRoam?12:0) + rng.nextInt(10)-5), description: 'Objektif ve çalı kontrolü, bilgi üstünlüğü.'),
      ];
      final s = <Metric>[
        Metric(title: 'Early Oyun Gücü', score: sc(50 + (hasJungle?12:0) + rng.nextInt(10)-5), description: 'Dakika 1–5 arası baskı ve çarpışma potansiyeli.'),
        Metric(title: 'Mid Oyun Rotasyonu', score: sc(52 + (hasMid?8:0) + rng.nextInt(10)-5), description: 'Dakika 6–12 arası rotasyon ve kule baskısı.'),
        Metric(title: 'Objektif Kontrolü', score: sc(54 + (hasRoam?8:0) + (hasJungle?6:0) + rng.nextInt(8)-4), description: 'Kaplumbağa/Lord ve kule baskısı koordinasyonu.'),
        Metric(title: 'Split Push Potansiyeli', score: sc(48 + (hasExp?10:0) + rng.nextInt(10)-5), description: 'Yan koridor itme ve harita yayılma gücü.'),
        Metric(title: 'Teamfight Uyum', score: sc(51 + lanesUsed.length*4 + rng.nextInt(8)-4), description: 'Rol senkronizasyonu ve yetenek zincirleme uyumu.'),
        Metric(title: 'Late Oyun Gücü', score: sc(53 + (hasGold?10:0) + rng.nextInt(10)-5), description: 'Dakika 15+ taşıyıcı performansı ve ölçeklenme.'),
      ];
      final mz = <Metric>[
        Metric(title: 'Meta Uyumu', score: sc(50 + (hasRoam?6:0) + (hasMid?6:0) + rng.nextInt(10)-5), description: 'Güncel meta ile sinerji ve karşı seçimlere dayanıklılık.'),
        Metric(title: 'Zorluk', score: sc(40 + (hasJungle?8:0) + rng.nextInt(10)-5), description: 'Kompozisyonun uygulanma ve koordinasyon zorluğu.'),
        Metric(title: 'Counter Hassasiyeti', score: sc(45 + rng.nextInt(12)-6), description: 'Rakip counter seçimlerine karşı kırılganlık.'),
        Metric(title: 'Draft Esnekliği', score: sc(48 + lanesUsed.length*3 + rng.nextInt(8)-4), description: 'Alternatif oyun planlarına uyum esnekliği.'),
      ];
      metrics = {
        MetricTab.general: g,
        MetricTab.strategy: s,
        MetricTab.metaDifficulty: mz,
      };
      int avgAll(){
        final all = [...g, ...s, ...mz];
        if (all.isEmpty) return 0;
        return (all.map((e)=>e.score).reduce((a,b)=>a+b)/all.length).round();
      }
      String tierOf(int sc){
        if (sc >= 90) return 'Tier: S';
        if (sc >= 80) return 'Tier: A';
        if (sc >= 70) return 'Tier: B';
        if (sc >= 60) return 'Tier: C';
        return 'Tier: D';
      }
      overall = avgAll().clamp(0,100);
      tierLabel = tierOf(overall);
      tierSubtitle = 'AI yoksa tarafsız tahmin: ortalama uyum.';
      badges = const [
        Badge(name: 'Erken Baskı', description: 'Dakika 4 hedef kontrol', iconPath: 'assets/icons/trophy.png'),
        Badge(name: 'Takım Uyum', description: 'Roller uyumlu', iconPath: 'assets/icons/star.png'),
      ];
    }
    result = FiveAnalysisResult(
      overallScore: overall,
      tierLabel: tierLabel,
      tierSubtitle: tierSubtitle,
      metrics: metrics,
      suggestions: aiSugs.isNotEmpty ? aiSugs : const [
        AiSuggestion('Erken oyun baskısı kur, jungler rotasyonunu hızlandır.'),
        AiSuggestion('Alt koridoru it, kule baskısı kur.'),
        AiSuggestion('Objektifler için görüş kontrolü al.'),
        AiSuggestion('Mid rotasyonlarını hızlandır, pick kovala.'),
        AiSuggestion('Build’leri BBML Build’den optimize et.'),
      ],
      badges: badges,
      bestScore: overall,
      bestScoreDate: DateTime.now(),
    );
    state = FiveAnalysisState.result;
    notifyListeners();
  }
}
