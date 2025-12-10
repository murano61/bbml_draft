import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import '../../services/ads_service.dart';
import '../../services/hero_repository.dart';
import '../../models/hero_model.dart';
import 'models.dart';
import 'controller.dart';
import 'five_analysis_empty_screen.dart';
import 'five_analysis_loading_screen.dart';
import 'five_analysis_result_screen.dart';

class FiveAnalysisFlow extends StatefulWidget {
  const FiveAnalysisFlow({super.key});
  @override
  State<FiveAnalysisFlow> createState() => _FiveAnalysisFlowState();
}

class _FiveAnalysisFlowState extends State<FiveAnalysisFlow> {
  final c = FiveAnalysisController();
  @override
  void dispose() { c.dispose(); super.dispose(); }
  void _selectFive() {
    final roles = [
      const HeroRole(name: 'Jungle', laneLabel: 'Jungle', iconPath: ''),
      const HeroRole(name: 'Gold', laneLabel: 'Gold Lane', iconPath: ''),
      const HeroRole(name: 'Mid', laneLabel: 'Mid Lane', iconPath: ''),
      const HeroRole(name: 'EXP', laneLabel: 'EXP Lane', iconPath: ''),
      const HeroRole(name: 'Roam', laneLabel: 'Roam', iconPath: ''),
    ];
    Navigator.push(context, MaterialPageRoute(builder: (_) => _HeroSelectFiveScreen(roles: roles))).then((res) {
      if (res is List<HeroPick> && res.isNotEmpty) {
        c.setPicks(res);
        if (mounted) setState(() {});
      }
    });
  }
  void _newFive() { c.reset(); setState(() {}); }
  void _replaceOne() { _selectFive(); }
  void _openBuilds() {}
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        switch (c.state) {
          case FiveAnalysisState.empty:
            return FiveAnalysisEmptyScreen(onSelectFive: _selectFive);
          case FiveAnalysisState.loading:
            return FiveAnalysisLoadingScreen(picks: c.picks);
          case FiveAnalysisState.result:
            return FiveAnalysisResultScreen(picks: c.picks, result: c.result!, onNewFive: _newFive, onReplaceOne: _replaceOne, onOpenBuilds: _openBuilds);
        }
      },
    );
  }
}

class _HeroSelectFiveScreen extends StatefulWidget {
  final List<HeroRole> roles;
  const _HeroSelectFiveScreen({required this.roles});
  @override
  State<_HeroSelectFiveScreen> createState() => _HeroSelectFiveScreenState();
}

class _HeroSelectFiveScreenState extends State<_HeroSelectFiveScreen> {
  List<HeroModel> _heroes = const [];
  final Map<String, HeroModel?> _selected = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  BannerAd? _banner;
  bool _bannerReady = false;
  @override
  void initState() {
    super.initState();
    for (final r in widget.roles) { _controllers[r.name] = TextEditingController(); }
    _load();
    _initBanner();
  }
  Future<void> _load() async {
    var heroes = await HeroRepository().getHeroesCached();
    if (heroes.isEmpty) heroes = await HeroRepository().getHeroes();
    setState(() { _heroes = heroes; _loading = false; });
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
  List<HeroModel> _filterByLane(String laneKey) {
    final lk = laneKey.toLowerCase();
    final pool = _heroes.where((h) => h.lanes.map((x) => x.toLowerCase()).contains(lk)).toList();
    return pool.isNotEmpty ? pool : _heroes;
  }
  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: const Text('5 Kahraman Seç')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: widget.roles.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i < widget.roles.length) {
              final role = widget.roles[i];
              final pool = _filterByLane(role.name);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role.laneLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Autocomplete<HeroModel>(
                  displayStringForOption: (h) => h.name(locale),
                  optionsBuilder: (text) {
                    final q = text.text.toLowerCase();
                    return pool.where((h) => h.name(locale).toLowerCase().contains(q));
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: SizedBox(
                          height: 240,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: options.map((h) {
                              final url = h.imageUrl;
                              final img = (url != null && url.isNotEmpty) ? NetworkImage(url) : null;
                              return ListTile(
                                leading: CircleAvatar(radius: 14, backgroundColor: Colors.black26, backgroundImage: img),
                                title: Text(h.name(locale)),
                                onTap: () => onSelected(h),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  onSelected: (h) {
                    setState(() { _selected[role.name] = h; _controllers[role.name]!.text = h.name(locale); });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    controller.text = _controllers[role.name]!.text;
                    final sel = _selected[role.name];
                    final url = sel?.imageUrl;
                    final img = (url != null && url.isNotEmpty) ? NetworkImage(url) : null;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: '${role.laneLabel} için kahraman',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: CircleAvatar(radius: 14, backgroundColor: Colors.black26, backgroundImage: img, child: img==null && sel!=null ? Text(sel.name(locale).characters.first.toUpperCase()) : null),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    );
                  },
                ),
              ]);
            }
            if (i == widget.roles.length) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_selected.length < widget.roles.length) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm rollere bir kahraman seçin')));
                      return;
                    }
                    final picks = <HeroPick>[];
                    for (final r in widget.roles) {
                      final h = _selected[r.name]!;
                      picks.add(HeroPick(heroName: h.name(locale), heroId: h.id, role: r, avatarPath: '', isSTier: false, imageUrl: h.imageUrl));
                    }
                    await AdsService.showInterstitial(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/2215412440' : null);
                    Navigator.pop(context, picks);
                  },
                  child: const Text('Analizi Başlat'),
                ),
              );
            }
            return SizedBox(height: AdsService.enabled && _banner != null && _bannerReady ? _banner!.size.height.toDouble() + 24 : 16);
          },
        ),
      ),
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
