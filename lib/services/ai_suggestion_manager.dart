import 'package:shared_preferences/shared_preferences.dart';

class AiSuggestionManager {
  static const int _freePerDay = 1;
  static const _keyLastDate = 'aiSuggestionLastDate';
  static const _keyUsedCount = 'aiSuggestionUsedCount';
  static const _keyWatchedAdsToday = 'aiSuggestionWatchedAdsToday';

  Future<void> resetIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final last = prefs.getString(_keyLastDate);
    if (last != today) {
      await prefs.setString(_keyLastDate, today);
      await prefs.setInt(_keyUsedCount, 0);
      await prefs.setInt(_keyWatchedAdsToday, 0);
    }
  }

  Future<int> getUsedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUsedCount) ?? 0;
  }

  Future<int> getWatchedAdsToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWatchedAdsToday) ?? 0;
  }

  Future<void> incrementUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_keyUsedCount) ?? 0) + 1;
    await prefs.setInt(_keyUsedCount, v);
  }

  Future<void> incrementWatchedAds() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_keyWatchedAdsToday) ?? 0) + 1;
    await prefs.setInt(_keyWatchedAdsToday, v);
  }

  Future<int> remainingFree() async {
    final used = await getUsedToday();
    final rem = _freePerDay - used;
    return rem > 0 ? rem : 0;
  }

  Future<int> bonusAvailable() async {
    final ads = await getWatchedAdsToday();
    final bonus = ads ~/ 2;
    final used = await getUsedToday();
    final extraConsumed = used - _freePerDay;
    final remainingBonus = bonus - (extraConsumed > 0 ? extraConsumed : 0);
    return remainingBonus > 0 ? remainingBonus : 0;
  }

  Future<int> remainingAdsToUnlockNext() async {
    final ads = await getWatchedAdsToday();
    final rem = 2 - (ads % 2);
    return rem;
  }

  Future<void> resetToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    await prefs.setString(_keyLastDate, today);
    await prefs.setInt(_keyUsedCount, 0);
    await prefs.setInt(_keyWatchedAdsToday, 0);
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
