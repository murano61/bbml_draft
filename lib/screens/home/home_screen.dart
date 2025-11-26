import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/locale_service.dart';
import '../../services/onesignal_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openSettings(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
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
              ListTile(title: const Text('Privacy Policy'), trailing: const Icon(Icons.open_in_new), onTap: () => _openWeb(context, K.privacyUrl)),
              ListTile(title: const Text('Apple Terms of Use'), trailing: const Icon(Icons.open_in_new), onTap: () => _openWeb(context, K.appleEulaUrl)),
              const SizedBox(height: 8),
              Text('settings_hint'.tr(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  Widget _featureCard(BuildContext context, {required IconData icon, required String title, required String desc, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
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
            _featureCard(
              context,
              icon: Icons.health_and_safety,
              title: 'home_my_counters_title'.tr(),
              desc: 'home_my_counters_desc'.tr(),
              onTap: () => Navigator.pushNamed(context, K.routeMyCounters),
            ),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.bar_chart,
              title: 'home_popular_title'.tr(),
              desc: 'home_popular_desc'.tr(),
              onTap: () => Navigator.pushNamed(context, K.routePopularHeroes),
            ),
          ],
        ),
      ),
      bottomNavigationBar: null,
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
