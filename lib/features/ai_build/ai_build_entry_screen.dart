import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class AiBuildEntryScreen extends StatelessWidget {
  const AiBuildEntryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = WebViewController();
    c.setJavaScriptMode(JavaScriptMode.unrestricted);
    c.addJavaScriptChannel('BBML_BUILD', onMessageReceived: (m){
      final v = m.message.toLowerCase();
      if (v.contains('hero')) { debugPrint('AI Build Entry -> Hero+Build tapped'); Navigator.pushNamed(context, K.routeAiHeroSelect); }
      if (v.contains('random')) { debugPrint('AI Build Entry -> Random Build tapped'); Navigator.pushNamed(context, K.routeAiRandomBuild); }
    });
    c.setNavigationDelegate(NavigationDelegate(onPageFinished: (url){
      c.runJavaScript("try{document.body.addEventListener('click',function(e){var t=(e.target.textContent||'').toLowerCase(); if(t.includes('kahraman')||t.includes('build')){BBML_BUILD.postMessage('hero');} if(t.includes('rastgele')){BBML_BUILD.postMessage('random');}});}catch(_){console.log('inject fail');}");
    }));
    Future(() async {
      try {
        final html = await rootBundle.loadString('assets/build_ai/ai_build_entry.html');
        await c.loadHtmlString(html);
      } catch (_) {
        debugPrint('AI Build Entry asset not found in stable path');
        await c.loadHtmlString('<html><body style="background:#0D0B1E;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh">Asset not found</body></html>');
      }
    });
    return Scaffold(appBar: AppBar(title: const Text('AI Build Asistanı')), body: WebViewWidget(controller: c));
  }

}
