import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/app_theme.dart';
import '../../services/locale_service.dart';
import '../../services/onesignal_service.dart';

class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({super.key});

  Map<String, (String name, String flag)> get _langs => {
        'tr': ('Türkçe', '🇹🇷'),
        'en': ('English', '🇺🇸'),
        'ru': ('Русский', '🇷🇺'),
        'id': ('Bahasa Indonesia', '🇮🇩'),
        'fil': ('Filipino', '🇵🇭'),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('language'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: K.supportedLocales.map((code) {
            final info = _langs[code] ?? (code.toUpperCase(), '');
            final selected = context.locale.languageCode == code;
            return ListTile(
              leading: Text(info.$2, style: const TextStyle(fontSize: 20)),
              title: Text(info.$1),
              trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () async {
                await context.setLocale(Locale(code));
                await LocaleService.setLocaleCode(code);
                await OneSignalService.setTags({'language': code});
                // Dil seçimi sonrası her zaman onboarding göster
                // Onboarding tamamlanınca Home'a geçilecek.
                // ignore: use_build_context_synchronously
                Navigator.pushReplacementNamed(context, K.routeOnboarding);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
