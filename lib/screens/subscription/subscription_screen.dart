import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;
import '../../services/ads_service.dart';
import '../../core/constants.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  WebViewController? _web;
  String? _html;
  BannerAd? _banner;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final tpl = await rootBundle.loadString('tasarimlar/abonelik/code.html');
      _html = tpl;
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.startsWith('bbml://')) {
              if (url.contains('back')) {
                Navigator.pop(context);
              } else if (url.contains('subscribe')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın alma hazırlanıyor')));
              } else if (url.contains('restore')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın almalar geri yükleniyor')));
              } else if (url.contains('terms')) {
                _openExternal(K.privacyUrl);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            await _bindJs();
          },
        ))
        ..loadHtmlString(_html!);
      _initBanner();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _initBanner() async {
    if (!AdsService.enabled) return;
    String unit = Platform.isAndroid ? 'ca-app-pub-2220990495085543/9607366049' : 'ca-app-pub-3940256099942544/2934735716';
    final ad = BannerAd(
      adUnitId: unit,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) { setState(() { _bannerReady = true; }); },
        onAdFailedToLoad: (ad, err) { ad.dispose(); },
      ),
    );
    await ad.load();
    _banner = ad;
  }

  Future<void> _bindJs() async {
    if (_web == null) return;
    await _web!.runJavaScript("""
      (function(){
        try {
          const backs = Array.from(document.querySelectorAll('.material-symbols-outlined'));
          if (backs.length>0){ backs[0].addEventListener('click', ()=>{ window.location.href='bbml://back'; }); }

          const priceEls = Array.from(document.querySelectorAll('span')).filter(el=> (el.textContent||'').includes('₺'));
          priceEls.forEach(el=> {
            const t = (el.textContent||'').trim();
            if (t.includes('129.99')) { el.textContent = '₺50.00'; }
          });

          const monthlyBtn = Array.from(document.querySelectorAll('button')).find(b=> (b.innerText||'').trim().toLowerCase().includes('bu planı seç'));
          if (monthlyBtn) { monthlyBtn.addEventListener('click', ()=>{ window.location.href='bbml://subscribe?product=monthly'; }); }

          const restoreBtn = Array.from(document.querySelectorAll('button')).find(b=> (b.innerText||'').trim().toLowerCase().includes('satın alımları geri yükle'));
          if (restoreBtn) { restoreBtn.addEventListener('click', ()=>{ window.location.href='bbml://restore'; }); }

          const termsBtn = Array.from(document.querySelectorAll('button')).find(b=> (b.innerText||'').trim().toLowerCase().includes('kullanım koşulları'));
          if (termsBtn) { termsBtn.addEventListener('click', ()=>{ window.location.href='bbml://terms'; }); }

          const yearlyCardTitle = Array.from(document.querySelectorAll('h1')).find(h=> (h.textContent||'').toLowerCase().includes('premium yıllık'));
          if (yearlyCardTitle) {
            const card = yearlyCardTitle.closest('div');
            if (card) { card.style.display = 'none'; }
          }
        } catch(e) {}
      })();
    """);
  }

  Future<void> _openExternal(String url) async {
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik')),
      body: _web == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _web!),
      bottomNavigationBar: AdsService.enabled && _banner != null && _bannerReady
          ? Container(
              height: _banner!.size.height.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _banner!),
            )
          : null,
    );
  }
}
