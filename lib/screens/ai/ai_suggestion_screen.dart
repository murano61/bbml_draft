import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/pill_chip.dart';
import '../../models/hero_model.dart';
import '../../services/hero_repository.dart';
import '../../services/ai_suggestion_manager.dart';
import '../../services/ads_service.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({super.key});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  final repo = HeroRepository();
  final manager = AiSuggestionManager();
  final _searchCtrl = TextEditingController();
  List<HeroModel> _heroes = [];
  HeroModel? _enemy;
  int _tab = 0; // 0: Rakip Seç, 1: Direkt Öneri
  final Set<String> _role = {};
  BannerAd? _banner;
  bool _bannerReady = false;
  int _freeRem = 0;
  int _bonusRem = 0;
  int _adsRem = 2;

  @override
  void initState() {
    super.initState();
    _load();
    _initBanner();
  }

  Future<void> _load() async {
    await manager.resetIfNewDay();
    _heroes = await repo.getHeroesCached();
    if (_heroes.isEmpty) { _heroes = await repo.getHeroes(); }
    setState(() {});
    await AdsService.init();
    _freeRem = await manager.remainingFree();
    _bonusRem = await manager.bonusAvailable();
    _adsRem = await manager.remainingAdsToUnlockNext();
    if (mounted) setState(() {});
  }

  Future<void> _refreshCounters() async {
    _freeRem = await manager.remainingFree();
    _bonusRem = await manager.bonusAvailable();
    _adsRem = await manager.remainingAdsToUnlockNext();
    if (mounted) setState(() {});
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

  String _infoText() {
    if (_freeRem > 0) return 'ai_free_today'.tr();
    if (_bonusRem <= 0) return 'ai_ads_need_n'.tr(args: [_adsRem.toString()]);
    return 'ai_info_counts'.tr(args: [_freeRem.toString(), _bonusRem.toString()]);
  }

  Future<void> _submit() async {
    await manager.resetIfNewDay();
    if (!mounted) return;
    if (_tab == 0 && _enemy == null) {
      _showSnack('Lütfen rakip kahramanı seçiniz.');
      return;
    }
    if (_role.isEmpty) {
      _showSnack('Lütfen rol seçiniz.');
      return;
    }
    setState(() {});
    await _refreshCounters();
    if (_freeRem <= 0 && _bonusRem <= 0) {
      int remainingAds = _adsRem;
      final okProceed = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          return AlertDialog(
            title: Text('ai_ads_confirm_title'.tr()),
            content: Text('ai_ads_need_n'.tr(args: [remainingAds.toString()])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('ai_ads_confirm_cancel'.tr())),
              TextButton(
                onPressed: () async {
                  final ok = await AdsService.showRewarded(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/7027813471' : null, onEarned: () async { await manager.incrementWatchedAds(); });
                  if (!ok) { _showSnack('ai_ads_fail'.tr()); return; }
                  remainingAds = remainingAds > 0 ? remainingAds - 1 : 0;
                  await _refreshCounters();
                  setStateDialog(() {});
                  if (remainingAds <= 0) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text('ai_ads_watch'.tr()),
              ),
            ],
          );
        });
      }) ?? false;
      if (!okProceed) return;
      await _refreshCounters();
    }
    Navigator.pushNamed(context, K.routeEnemyPickResult, arguments: {
      'enemyHeroId': _tab == 0 ? _enemy?.id : null,
      'role': _role.toList(),
      'ai': true,
    });
  }

  

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
        title: Text('ai_title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ai_page_hint'.tr(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _segButton('ai_tab_enemy'.tr(), selected: _tab == 0, onTap: () { setState(() { _tab = 0; }); })),
              const SizedBox(width: 8),
              Expanded(child: _segButton('ai_tab_direct'.tr(), selected: _tab == 1, onTap: () { setState(() { _tab = 1; _enemy = null; _searchCtrl.clear(); }); })),
            ]),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              _heroSearch(),
              const SizedBox(height: 12),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: ['Gold', 'EXP', 'Jungle', 'Mid', 'Roam'].map((r) {
              final selected = _role.contains(r);
              return PillChip(label: r, selected: selected, onTap: () {
                setState(() {
                  if (selected) { _role.remove(r); } else { _role.add(r); }
                });
              });
            }).toList()),
            const SizedBox(height: 20),
            Text(_infoText(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            const SizedBox(height: 0),
            PrimaryButton(label: 'ai_get_suggestion'.tr(), onPressed: _submit),
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

  Widget _segButton(String label, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primary : AppColors.card,
          border: Border.all(color: AppColors.primary.withAlpha(((selected ? 1.0 : 0.5) * 255).round())),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _heroSearch() {
    return Autocomplete<HeroModel>(
      displayStringForOption: (h) => h.name(context.locale.languageCode),
      optionsBuilder: (text) {
        final q = text.text.toLowerCase();
        return _heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
      },
      onSelected: (h) {
        _enemy = h;
        _searchCtrl.text = h.name(context.locale.languageCode);
        setState(() {});
      },
      fieldViewBuilder: (context2, controller, focusNode, onFieldSubmitted) {
        controller.text = _searchCtrl.text;
        controller.addListener(() { _searchCtrl.text = controller.text; });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'ai_search_hint'.tr(),
            prefixIcon: const Icon(Icons.search),
          ),
        );
      },
    );
  }
}
