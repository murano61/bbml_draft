import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../../models/hero_model.dart';
import '../../services/hero_repository.dart';
import '../../services/firebase_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class PopularHeroesScreen extends StatefulWidget {
  const PopularHeroesScreen({super.key});

  @override
  State<PopularHeroesScreen> createState() => _PopularHeroesScreenState();
}

class _PopularHeroesScreenState extends State<PopularHeroesScreen> {
  final repo = HeroRepository();
  List<(HeroModel, int)> _stats = [];
  bool _loading = false;
  List<HeroModel> _featured = [];
  BannerAd? _banner;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    _load();
    _initBanner();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final heroes = await repo.getHeroes();
    _featured = _pickRandom(heroes, 3);
    try {
      if (FirebaseService.isInitialized) {
        final snap = await FirebaseService.db.collection('hero_stats').orderBy('totalSearchCount', descending: true).limit(50).get();
        final entries = snap.docs.map((d) {
          final heroId = d.id;
          final count = d.data()['totalSearchCount'] ?? 0;
          final hero = heroes.firstWhere((h) => h.id == heroId, orElse: () => heroes.isNotEmpty ? heroes.first : HeroModel(id: heroId, names: {'en': heroId}, roles: ['Unknown']));
          return (hero, count as int);
        }).toList();
        _stats = entries.isEmpty
            ? [
                if (heroes.isNotEmpty) (heroes[0], 0),
                if (heroes.length > 1) (heroes[1], 0),
                if (heroes.length > 2) (heroes[2], 0),
              ]
            : entries;
      } else {
        final counts = [2345, 1987, 1560];
        final n = heroes.length < 3 ? heroes.length : 3;
        _stats = List.generate(n, (i) => (heroes[i], counts[i]));
      }
    } catch (_) {
      final counts = [2345, 1987, 1560];
      final n = heroes.length < 3 ? heroes.length : 3;
      _stats = List.generate(n, (i) => (heroes[i], counts[i]));
    }
    setState(() => _loading = false);
  }

  List<HeroModel> _pickRandom(List<HeroModel> heroes, int n) {
    if (heroes.isEmpty) return [];
    final pool = List<HeroModel>.from(heroes);
    final res = <HeroModel>[];
    final rnd = Random(DateTime.now().millisecondsSinceEpoch);
    for (var i = 0; i < n && pool.isNotEmpty; i++) {
      final idx = rnd.nextInt(pool.length);
      res.add(pool.removeAt(idx));
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    const colorPrimary = Color(0xFF00FF00);
    const colorBackground = Color(0xFF1A1A1A);
    const colorSurface = Color(0xFF2C2C2C);
    const colorTextLight = Color(0xFFE0E0E0);
    // removed border dark as background grid is removed
    const accentRed = Color(0xFFFF3333);
    const accentBlue = Color(0xFF3399FF);

    final display = GoogleFonts.orbitron();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorSurface,
        title: Text('HERO ÖNERİLERİ', style: display.copyWith(color: colorPrimary, fontSize: 16, letterSpacing: 0.8)),
      ),
      backgroundColor: colorBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ÖNE ÇIKAN 3 KAHRAMAN', style: display.copyWith(color: colorTextLight, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _featuredPanel(context, display, colorPrimary, accentBlue, accentRed, colorTextLight),
                  const SizedBox(height: 24),
                  Text('EN FAZLA ARAŞTIRILANLAR', style: display.copyWith(color: colorTextLight, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _topList(context, display, colorSurface, colorTextLight, accentBlue),
                ]),
              ),
            ),
      bottomNavigationBar: _banner != null && _bannerReady
          ? Container(
              height: _banner!.size.height.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _banner!),
            )
          : null,
    );
  }

  

  Widget _featuredPanel(BuildContext context, TextStyle display, Color neon, Color blue, Color red, Color textLight) {
    final top = _featured.isNotEmpty ? _featured.take(3).toList() : _stats.take(3).map((e) => e.$1).toList();
    return Row(children: List.generate(top.length, (i) {
      final hero = top[i];
      Color border = [neon, blue, red][i];
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: i < top.length - 1 ? 8 : 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            border: Border.all(color: border.withAlpha((0.6 * 255).round())),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: border.withAlpha((0.3 * 255).round()),
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 120,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
              child: _heroImage(hero),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  hero.name(context.locale.languageCode).toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: display.copyWith(color: textLight, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ]),
        ),
      );
    }));
  }

  Widget _topList(BuildContext context, TextStyle display, Color surface, Color textLight, Color accent) {
    final top = _stats.take(10).toList();
    return Column(children: List.generate(top.length, (i) {
      final (hero, count) = top[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: accent.withAlpha((0.5 * 255).round()))),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: accent)),
            child: _heroImage(hero),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hero.name(context.locale.languageCode),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: display.copyWith(color: textLight, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text('${'Araştırma sayısı'}: $count', style: display.copyWith(color: textLight.withAlpha((0.8 * 255).round()), fontSize: 12)),
            ]),
          ),
          Text('#${i + 1}', style: display.copyWith(color: accent, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      );
    }));
  }

  

  Widget _heroImage(HeroModel h) {
    final url = (h.imageUrl ?? '').trim();
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 512,
        memCacheHeight: 384,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholderFadeInDuration: const Duration(milliseconds: 80),
        placeholder: (context, _) => _fallbackImage(h),
        errorWidget: (context, _, __) => _fallbackImage(h),
      );
    }
    return _fallbackImage(h);
  }

  Widget _fallbackImage(HeroModel h) {
    return Container(
      color: const Color(0xFF2C2C2C),
      alignment: Alignment.center,
      child: Text(h.id.toUpperCase(), style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _initBanner() async {
    final unit = 'ca-app-pub-2220990495085543/9607366049';
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
}
