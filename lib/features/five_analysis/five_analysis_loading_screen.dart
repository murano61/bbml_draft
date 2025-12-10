import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'models.dart';

class FiveAnalysisLoadingScreen extends StatefulWidget {
  final List<HeroPick> picks;
  const FiveAnalysisLoadingScreen({super.key, required this.picks});
  @override
  State<FiveAnalysisLoadingScreen> createState() => _FiveAnalysisLoadingScreenState();
}

class _FiveAnalysisLoadingScreenState extends State<FiveAnalysisLoadingScreen> {
  WebViewController? _web;
  @override
  void initState() {
    super.initState();
    Future(() async {
      final tpl = await rootBundle.loadString("tasarimlar/yeni sayfa/5'li_analiz_ekranı_(sonuç_görünümü)_2/code.html");
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(tpl);
      setState(() => _web = c);
      // Optionally inject hero lane labels later when we bind real avatars
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('5’li Analiz')), body: _web==null? const Center(child: CircularProgressIndicator()): WebViewWidget(controller: _web!));
  }
}
