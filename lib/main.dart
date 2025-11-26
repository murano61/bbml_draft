import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'core/localization.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/enemy_pick/enemy_pick_screen.dart';
import 'screens/enemy_pick/enemy_pick_result_screen.dart';
import 'screens/my_counters/my_counters_screen.dart';
import 'screens/popular_heroes/popular_heroes_screen.dart';
import 'screens/language/language_select_screen.dart';
import 'services/locale_service.dart';
import 'services/firebase_service.dart';
import 'services/onesignal_service.dart';
import 'firebase_options.dart';
import 'services/hero_repository.dart';
import 'dart:ui' as ui;
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await FirebaseService.init(options: DefaultFirebaseOptions.currentPlatform);

  if (Platform.isIOS || Platform.isAndroid) {
    await OneSignalService.init(appId: '19acde23-74f2-4660-99ea-cc9b15197f14');
    final localeCode = await LocaleService.getLocaleCode();
    final language = localeCode ?? ui.PlatformDispatcher.instance.locale.languageCode;
    final tz = DateTime.now().timeZoneName;
    await OneSignalService.setTags({'language': language, 'tz': tz});
  }
  final seeded = await LocaleService.getSeeded();
  if (!seeded) {
    await HeroRepository().seedSampleData();
    await LocaleService.setSeeded(true);
  }

  final startLocaleCode = await LocaleService.getLocaleCode();
  runApp(EasyLocalization(
    supportedLocales: LocalizationConfig.supportedLocales,
    path: LocalizationConfig.path,
    fallbackLocale: const Locale('en'),
    startLocale: Locale(startLocaleCode ?? 'en'),
    useOnlyLangCode: true,
    child: const App(),
  ));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _loaded = false;
  static final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

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
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return MaterialApp(
      title: K.appName,
      theme: buildDarkTheme(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorKey: _navKey,
      home: const HomeScreen(),
      routes: {
        K.routeOnboarding: (_) => const OnboardingScreen(),
        K.routeHome: (_) => const HomeScreen(),
        K.routeEnemyPick: (_) => const EnemyPickScreen(),
        K.routeEnemyPickResult: (_) => const EnemyPickResultScreen(),
        K.routeMyCounters: (_) => const MyCountersScreen(),
        K.routePopularHeroes: (_) => const PopularHeroesScreen(),
        K.routeLanguage: (_) => const LanguageSelectScreen(),
      },
    );
  }
}
