import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import 'dart:async';

class AdsService {
  static bool _initialized = false;
  static bool enabled = false;
  static int _clicks = 0;

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  static Future<bool> showRewarded({String? adUnitId, required VoidCallback onEarned}) async {
    if (!enabled) { onEarned(); return true; }
    final unit = adUnitId ?? (Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313');
    try {
      final completer = Completer<bool>();
      bool earned = false;
      await RewardedAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (a) {
            a.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(earned);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            a.show(onUserEarnedReward: (ad, reward) {
              earned = true;
              onEarned();
            });
          },
          onAdFailedToLoad: (err) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showInterstitial({String? adUnitId}) async {
    if (!enabled) return false;
    final unit = adUnitId ?? (Platform.isAndroid
        ? 'ca-app-pub-2220990495085543/2215412440'
        : 'ca-app-pub-3940256099942544/4411468910');
    try {
      final completer = Completer<bool>();
      await InterstitialAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(true);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (err) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showRewardedInterstitial({String? adUnitId}) async {
    if (!enabled) return false;
    final unit = adUnitId ?? (Platform.isAndroid
        ? 'ca-app-pub-2220990495085543/9163022223'
        : 'ca-app-pub-3940256099942544/6978759866');
    try {
      final completer = Completer<bool>();
      await RewardedInterstitialAd.load(
        adUnitId: unit,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(true);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (ad, reward) {});
          },
          onAdFailedToLoad: (err) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  static Future<void> maybeShowInterstitial({String? adUnitId, int every = 3}) async {
    if (!enabled) return;
    _clicks++;
    final n = every <= 0 ? 3 : every;
    if (_clicks % n == 0) {
      await showInterstitial(adUnitId: adUnitId);
    }
  }
}
