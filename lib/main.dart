import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import "core/localization.dart";
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/enemy_pick/enemy_pick_screen.dart';
import 'screens/enemy_pick/enemy_pick_result_screen.dart';
import 'screens/my_counters/my_counters_screen.dart';
import 'screens/popular_heroes/popular_heroes_screen.dart';
import 'screens/language/language_select_screen.dart';
import 'screens/ai/ai_suggestion_screen.dart';
import 'screens/subscription/subscription_screen.dart';
import 'features/five_analysis/five_analysis_flow.dart';
import 'features/draft_power/draft_power_screen.dart';
import 'features/ai_build/ai_build_entry_screen.dart';
import 'features/ai_build/ai_hero_select_screen.dart';
import 'features/ai_build/ai_hero_build_screen.dart';
import 'features/ai_build/ai_random_build_screen.dart';
 
 
import 'services/locale_service.dart';
import 'services/firebase_service.dart';
import 'services/onesignal_service.dart';
import 'firebase_options.dart';
import 'services/hero_repository.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/gemini_service.dart';
import 'services/ads_service.dart';
 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    return true;
  };

  await EasyLocalization.ensureInitialized();

  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    await FirebaseService.init(options: DefaultFirebaseOptions.currentPlatform);
  } else {
    await FirebaseService.init();
  }

  const bootstrapKey = String.fromEnvironment('BOOTSTRAP_GEMINI_KEY');
  if (bootstrapKey.isNotEmpty) {
    try { await GeminiService().setApiKey(bootstrapKey); } catch (_) {}
  }

  final startLocaleCode = await LocaleService.getLocaleCode();

  runZonedGuarded(() {
    runApp(EasyLocalization(
      supportedLocales: LocalizationConfig.supportedLocales,
      path: LocalizationConfig.path,
      fallbackLocale: const Locale('en'),
      startLocale: Locale(startLocaleCode ?? 'en'),
      useOnlyLangCode: true,
      child: const App(),
    ));
  }, (e, s) {});
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _loaded = false;
  static final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  String? _localeCodeStored;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _prepare();
    OneSignalService.configureClickHandler((data) {
      final target = (data ?? {})['navigate'];
      final route = switch (target) {
        'home' => K.routeHome,
        'enemy_pick' => K.routeEnemyPick,
        'my_counters' => K.routeMyCounters,
        'popular_heroes' => K.routePopularHeroes,
        _ => K.routeHome,
      };
      _navKey.currentState?.pushNamedAndRemoveUntil(route, (r) => false);
    });
  }

  Future<void> _prepare() async {
    setState(() => _loaded = true);
    try {
      var heroes = await HeroRepository().getHeroesCached();
      if (heroes.isEmpty) { heroes = HeroRepository().getHeroesLocal(); }
    } catch (_) {}
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
    try {
      AdsService.enabled = true;
      await AdsService.init();
    } catch (_) {}
    try {
      _localeCodeStored = await LocaleService.getLocaleCode();
      _hasSeenOnboarding = await LocaleService.getHasSeenOnboarding();
    } catch (_) {}
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        await OneSignalService.init(appId: '19acde23-74f2-4660-99ea-cc9b15197f14');
        final localeCode = await LocaleService.getLocaleCode();
        final language = localeCode ?? ui.PlatformDispatcher.instance.locale.languageCode;
        final tz = DateTime.now().timeZoneName;
        await OneSignalService.setTags({'language': language, 'tz': tz});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    final routes = {
      K.routeOnboarding: (_) => const OnboardingScreen(),
      K.routeHome: (_) => const HomeScreen(),
      K.routeEnemyPick: (_) => const EnemyPickScreen(),
      K.routeEnemyPickResult: (_) => const EnemyPickResultScreen(),
      K.routeMyCounters: (_) => const MyCountersScreen(),
      K.routePopularHeroes: (_) => const PopularHeroesScreen(),
      K.routeLanguage: (_) => const LanguageSelectScreen(),
      K.routeAiSuggestion: (_) => const AiSuggestionScreen(),
      K.routeSubscription: (_) => const SubscriptionScreen(),
      K.routeFiveAnalysis: (_) => const FiveAnalysisFlow(),
      K.routeDraftPower: (_) => const DraftPowerScreen(),
      K.routeAiBuildEntry: (_) => const AiBuildEntryScreen(),
      K.routeAiHeroSelect: (_) => const AiHeroSelectScreen(),
      K.routeAiHeroBuild: (_) => const AiHeroBuildScreen(hero: null),
      K.routeAiRandomBuild: (_) => const AiRandomBuildScreen(),
    };
    final initialHome = _localeCodeStored == null
        ? const LanguageSelectScreen()
        : (_hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen());
    return MaterialApp(
      title: K.appName,
      theme: buildDarkTheme(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorKey: _navKey,
      home: initialHome,
      routes: routes,
    );
  }
}
