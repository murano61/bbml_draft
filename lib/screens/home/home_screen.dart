import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/locale_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/ads_service.dart';
import '../../services/ai_suggestion_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _banner;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    MobileAds.instance.initialize().then((_) => _initBanner());
  }

  Future<void> _initBanner() async {
    if (!AdsService.enabled) return;
    String unit = Platform.isAndroid ? 'ca-app-pub-2220990495085543/9607366049' : 'ca-app-pub-3940256099942544/2934735716';
    BannerAd? ad;
    Future<bool> load(String u) async {
      final b = BannerAd(
        adUnitId: u,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) { setState(() { _bannerReady = true; }); },
          onAdFailedToLoad: (ad, err) { ad.dispose(); },
        ),
      );
      ad = b;
      try { await b.load(); return true; } catch (_) { return false; }
    }
    final ok = await load(unit);
    if (!ok) {
      unit = Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
      await load(unit);
    }
    _banner = ad;
  }

  void _openSettings(BuildContext context) async {
    final existingKey = await GeminiService().getApiKey();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('settings'.tr(), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('language'.tr()),
                  const SizedBox(height: 8),
                  _LanguageList(),
                  const SizedBox(height: 16),
                  if (kDebugMode) ...[
                    Text('Gemini API Anahtarı (Debug)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.5)),
                        color: AppColors.card,
                      ),
                      child: Text(existingKey ?? '(boş)', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ListTile(title: Text('settings_subscription'.tr()), trailing: const Icon(Icons.credit_card), onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, K.routeSubscription);
                  }),
                  const SizedBox(height: 8),
                  
                  ListTile(title: const Text('Günlük AI hakkını sıfırla'), trailing: const Icon(Icons.refresh), onTap: () async {
                    final ok = await showDialog<bool>(context: context, builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Günlük hakkı sıfırla'),
                        content: const Text('Bugünkü ücretsiz ve reklam haklarını sıfırlamak istiyor musunuz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sıfırla')),
                        ],
                      );
                    });
                    if (ok == true) {
                      await AiSuggestionManager().resetToday();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Günlük AI hakkı sıfırlandı')));
                    }
                  }),
                  ListTile(title: const Text('Privacy Policy'), trailing: const Icon(Icons.open_in_new), onTap: () => _openWeb(context, K.privacyUrl)),
                  ListTile(title: const Text('Apple Terms of Use'), trailing: const Icon(Icons.open_in_new), onTap: () => _openWeb(context, K.appleEulaUrl)),
                  const Divider(),

                  const SizedBox(height: 8),
                  Text('settings_hint'.tr(), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureCard(BuildContext context, {required IconData icon, required String title, required String desc, required VoidCallback onTap}) {
    return InkWell(
      onTap: () async {
        await AdsService.maybeShowInterstitial(adUnitId: Platform.isAndroid ? 'ca-app-pub-2220990495085543/2215412440' : null);
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentPurple, width: 1.2),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
          gradient: const LinearGradient(colors: [Color(0xFF1F1A3F), Color(0xFF1A1640)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: AppColors.accentPurple),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('home_title'.tr()),
        actions: [
          IconButton(onPressed: () => _openSettings(context), icon: const Icon(Icons.settings)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            _featureCard(
              context,
              icon: Icons.sports_martial_arts,
              title: 'home_enemy_pick_title'.tr(),
              desc: 'home_enemy_pick_desc'.tr(),
              onTap: () => Navigator.pushNamed(context, K.routeEnemyPick),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.bar_chart,
              title: 'home_popular_title'.tr(),
              desc: 'home_popular_desc'.tr(),
              onTap: () => Navigator.pushNamed(context, K.routePopularHeroes),
            ),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.memory,
              title: 'home_ai_title'.tr(),
              desc: 'home_ai_desc'.tr(),
              onTap: () => Navigator.pushNamed(context, K.routeAiSuggestion),
            ),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.grid_view,
              title: '5’li Analiz',
              desc: 'Takımını analiz et, skor ve öneriler al.',
              onTap: () => Navigator.pushNamed(context, K.routeFiveAnalysis),
            ),
            const SizedBox(height: 12),
          _featureCard(
            context,
            icon: Icons.auto_graph,
            title: 'Draft Güç Analizi',
            desc: 'Draft gücü, eşleşmeler ve kompozisyon karşılaştırması.',
            onTap: () => Navigator.pushNamed(context, K.routeDraftPower),
          ),
          const SizedBox(height: 12),
          ],
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

  class _LangChip extends StatelessWidget {
  final String code;
  const _LangChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final selected = context.locale.languageCode == code;
    final name = {
      'tr': 'Türkçe',
      'en': 'English',
      'ru': 'Русский',
      'id': 'Bahasa Indonesia',
      'fil': 'Filipino',
    }[code] ?? code;
    final flag = {
      'tr': '🇹🇷',
      'en': '🇺🇸',
      'ru': '🇷🇺',
      'id': '🇮🇩',
      'fil': '🇵🇭',
    }[code] ?? '';
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(name),
      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () async {
        await context.setLocale(Locale(code));
        await LocaleService.setLocaleCode(code);
        await OneSignalService.setTags({'language': code});
        if (!context.mounted) return;
        Navigator.pop(context);
      },
    );
  }
}

  class _LanguageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const codes = K.supportedLocales;
    return Column(children: codes.map((c) => _LangChip(code: c)).toList());
  }
}
  void _openWeb(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url));
        return SafeArea(child: SizedBox(height: MediaQuery.of(context).size.height * 0.9, child: WebViewWidget(controller: controller)));
      },
    );
  }
