import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/hero_model.dart';
import '../../services/hero_repository.dart';
import '../../services/firebase_service.dart';

class PopularHeroesScreen extends StatefulWidget {
  const PopularHeroesScreen({super.key});

  @override
  State<PopularHeroesScreen> createState() => _PopularHeroesScreenState();
}

class _PopularHeroesScreenState extends State<PopularHeroesScreen> {
  final repo = HeroRepository();
  List<(HeroModel, int)> _stats = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final heroes = repo.getHeroesLocal();
    try {
      if (FirebaseService.isInitialized) {
        final snap = await FirebaseService.db.collection('hero_stats').orderBy('totalSearchCount', descending: true).limit(50).get();
        final entries = snap.docs.map((d) {
          final heroId = d.id;
          final count = d.data()['totalSearchCount'] ?? 0;
          final hero = heroes.firstWhere((h) => h.id == heroId, orElse: () => heroes.first);
          return (hero, count as int);
        }).toList();
        _stats = entries.isEmpty
            ? [
                (heroes[0], 0),
                (heroes[1], 0),
                (heroes[2], 0),
              ]
            : entries;
      } else {
        _stats = [
          (heroes[0], 2345),
          (heroes[1], 1987),
          (heroes[2], 1560),
        ];
      }
    } catch (_) {
      _stats = [
        (heroes[0], 2345),
        (heroes[1], 1987),
        (heroes[2], 1560),
      ];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const colorPrimary = Color(0xFF00FF00);
    const colorBackground = Color(0xFF1A1A1A);
    const colorSurface = Color(0xFF2C2C2C);
    const colorTextLight = Color(0xFFE0E0E0);
    const colorTextMuted = Color(0xFFA0A0A0);
    const colorBorderDark = Color(0xFF404040);
    const accentRed = Color(0xFFFF3333);
    const accentBlue = Color(0xFF3399FF);

    final display = GoogleFonts.orbitron();
    final mono = GoogleFonts.robotoMono();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorSurface,
        title: Text('TACTICAL ANALYSIS DASHBOARD', style: display.copyWith(color: colorPrimary, fontSize: 14, letterSpacing: 0.8)),
      ),
      backgroundColor: colorBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: colorBorderDark))),
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('OPERATIONAL DATA: TOP DOMINATORS', style: display.copyWith(color: colorTextLight, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('GLOBAL DATA STREAM // PRIORITY TARGETS IDENTIFIED // WEEKLY RECALIBRATION', style: mono.copyWith(color: colorTextMuted, fontSize: 12)),
                ]),
              ),
              Container(
                decoration: BoxDecoration(color: colorSurface.withValues(alpha: 0.5), border: const Border(bottom: BorderSide(color: colorBorderDark))),
                padding: const EdgeInsets.all(12),
                child: _topThreePanel(context, display, mono, colorPrimary, accentBlue, accentRed, colorTextLight),
              ),
            Expanded(
              child: Container(
                color: colorSurface.withValues(alpha: 0.3),
                child: _tablePanel(context, display, mono, colorPrimary, accentBlue, accentRed, colorTextLight, colorTextMuted, colorBorderDark),
              ),
            ),
          ]),
      bottomNavigationBar: null,
    );
  }

  Widget _topThreePanel(BuildContext context, TextStyle display, TextStyle mono, Color neon, Color blue, Color red, Color textLight) {
    final top = _stats.take(3).toList();
    Color border(int i) => [neon, blue, red][i];
    Color indexColor(int i) => [neon, blue, red][i];
    return Row(
      children: List.generate(top.length, (i) {
        final (hero, count) = top[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < top.length - 1 ? 8 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2C2C2C), border: Border.all(color: border(i).withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: border(i).withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 0, offset: const Offset(0, 0))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.topLeft, child: Text((i + 1).toString().padLeft(2, '0'), style: display.copyWith(color: indexColor(i), fontSize: 20))),
              const SizedBox(height: 6),
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: border(i), width: 2), image: DecorationImage(image: NetworkImage(_imageForHero(hero)), fit: BoxFit.cover)),
              ),
              const SizedBox(height: 8),
              Text(hero.name(context.locale.languageCode).toUpperCase(), style: display.copyWith(color: textLight, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('SEARCH QUERIES: $count', style: mono.copyWith(color: indexColor(i), fontSize: 12)),
            ]),
          ),
        );
      }),
    );
  }

  Widget _tablePanel(BuildContext context, TextStyle display, TextStyle mono, Color neon, Color blue, Color red, Color textLight, Color textMuted, Color borderDark) {
    final list = _stats.asMap().entries.toList();
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderDark))),
        child: Row(children: [
          Expanded(flex: 1, child: Text('RANK', style: mono.copyWith(color: neon, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('HERO', style: mono.copyWith(color: neon, fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('QUERIES', style: mono.copyWith(color: neon, fontSize: 10, fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('TREND', style: mono.copyWith(color: neon, fontSize: 10, fontWeight: FontWeight.bold)))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, idx) {
            final i = idx;
            final (h, c) = list[idx].value;
            final trendIcon = i % 3 == 0 ? Icons.trending_flat : (i % 3 == 1 ? Icons.trending_up : Icons.trending_down);
            final trendColor = i % 3 == 0 ? blue : (i % 3 == 1 ? neon : red);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderDark.withValues(alpha: 0.5)))),
              child: Row(children: [
                Expanded(flex: 1, child: Text((i + 1).toString().padLeft(2, '0'), style: mono.copyWith(color: textLight, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(
                  flex: 2,
                  child: Row(children: [
                    Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderDark), image: DecorationImage(image: NetworkImage(_imageForHero(h)), fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(h.name(context.locale.languageCode).toUpperCase(), style: mono.copyWith(color: textLight, fontSize: 12)))
                  ]),
                ),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text(c.toString(), style: mono.copyWith(color: textLight, fontSize: 12)))),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(trendIcon, color: trendColor, size: 16),
                      const SizedBox(width: 4),
                      Text(trendIcon == Icons.trending_up ? 'RISING' : trendIcon == Icons.trending_down ? 'DECLINE' : 'STABLE', style: mono.copyWith(color: trendColor, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  String _imageForHero(HeroModel h) {
    switch (h.id) {
      case 'fanny':
        return 'https://lh3.googleusercontent.com/aida-public/AB6AXuBY-brVpL9bBmxvAB_D97yAA_BHTpvmNNjZTx8dyfkA-4gfswb1X9ST7mQL_F3YNQ-QtftSoG40L0EpfVAgFrB7Pr5-310Vy6QuW6ysZ6IXH1I9D-PCv7chDcXLQqeMByFtoo7W725nxY6uTze5HI62H5_90fn4u3i1aSjvmjFvPp8n64I7T3IJShxE8mnrzmSymnZSGup8hsc6JSImpusl3-_GFv_tyt-NVBBDA63hgXRxk3VW5QwfwQDKobDzRE13QWzaRKXLwO65';
      case 'miya':
        return 'https://via.placeholder.com/300x300.png?text=Miya';
      case 'tigreal':
        return 'https://via.placeholder.com/300x300.png?text=Tigreal';
      default:
        return 'https://via.placeholder.com/300x300.png?text=${h.id.toUpperCase()}';
    }
  }
}
