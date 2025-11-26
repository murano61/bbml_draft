import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init({required String appId}) async {
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      OneSignal.initialize(appId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        try {} catch (_) {}
      });
      _initialized = true;
    } catch (e) {
      debugPrint('OneSignal init failed: $e');
      _initialized = false;
    }
  }

  static Future<void> setTags(Map<String, String> tags) async {
    if (!_initialized) return;
    try {
      await OneSignal.User.addTags(tags);
    } catch (e) {
      debugPrint('OneSignal setTags failed: $e');
    }
  }

  static void configureClickHandler(void Function(Map<String, dynamic>?) onClick) {
    if (!_initialized) return;
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      onClick(data);
    });
  }
}
