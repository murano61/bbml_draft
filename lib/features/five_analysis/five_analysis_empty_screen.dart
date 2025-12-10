import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class FiveAnalysisEmptyScreen extends StatefulWidget {
  final VoidCallback onSelectFive;
  const FiveAnalysisEmptyScreen({super.key, required this.onSelectFive});
  @override
  State<FiveAnalysisEmptyScreen> createState() => _FiveAnalysisEmptyScreenState();
}

class _FiveAnalysisEmptyScreenState extends State<FiveAnalysisEmptyScreen> {
  WebViewController? _web;
  @override
  void initState() {
    super.initState();
    Future(() async {
      final tpl = await rootBundle.loadString("tasarimlar/yeni sayfa/5'li_analiz_ekranı_(sonuç_görünümü)_1/code.html");
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (req) {
            if (req.url.startsWith('bbml://selectFive')) {
              widget.onSelectFive();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) async {
            await _web?.runJavaScript("""
              (function(){
                const bindSelect = ()=>{
                  const btns = Array.from(document.querySelectorAll('button'));
                  btns.forEach(b=>{
                    const t=(b.innerText||'').trim().toLowerCase();
                    if(t.includes('5 kahraman seç')){
                      b.addEventListener('click', ()=>{ window.location.href='bbml://selectFive'; });
                    }
                  });
                  const adds = Array.from(document.querySelectorAll('.material-symbols-outlined'));
                  adds.forEach(i=>{
                    if((i.textContent||'').trim()==='add'){
                      const target = i.closest('div');
                      (target||i).addEventListener('click', ()=>{ window.location.href='bbml://selectFive'; });
                    }
                  });
                };
                bindSelect();
              })();
            """);
          }
        ))
        ..loadHtmlString(tpl);
      setState(() => _web = c);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('5’li Analiz')), body: _web==null? const Center(child: CircularProgressIndicator()): WebViewWidget(controller: _web!));
  }
}
