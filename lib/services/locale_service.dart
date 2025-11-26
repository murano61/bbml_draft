import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static Future<bool> getHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeenOnboarding') ?? false;
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', value);
  }

  static Future<String?> getLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('localeCode');
  }

  static Future<void> setLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localeCode', code);
  }

  static Future<bool> getSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSeededSampleData') ?? false;
  }

  static Future<void> setSeeded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeededSampleData', value);
  }
}
