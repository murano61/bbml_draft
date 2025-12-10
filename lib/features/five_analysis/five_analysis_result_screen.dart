import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'models.dart';
import 'dart:convert';
import '../../services/hero_repository.dart';

class FiveAnalysisResultScreen extends StatefulWidget {
  final List<HeroPick> picks;
  final FiveAnalysisResult result;
  final VoidCallback onNewFive;
  final VoidCallback onReplaceOne;
  final VoidCallback onOpenBuilds;
  const FiveAnalysisResultScreen({super.key, required this.picks, required this.result, required this.onNewFive, required this.onReplaceOne, required this.onOpenBuilds});
  @override
  State<FiveAnalysisResultScreen> createState() => _FiveAnalysisResultScreenState();
}

class _FiveAnalysisResultScreenState extends State<FiveAnalysisResultScreen> {
  WebViewController? _web;
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('5’li Analiz')), body: _web==null? const Center(child: CircularProgressIndicator()): WebViewWidget(controller: _web!));
  }
  @override
  void initState() {
    super.initState();
    Future(() async {
      final tpl = await rootBundle.loadString("tasarimlar/yeni sayfa/5'li_analiz_ekranı_(sonuç_görünümü)_3/code.html");
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (req) {
            final url = req.url;
            if (url.startsWith('bbml://new')) { widget.onNewFive(); return NavigationDecision.prevent; }
            if (url.startsWith('bbml://replace')) { widget.onReplaceOne(); return NavigationDecision.prevent; }
            if (url.startsWith('bbml://builds')) { widget.onOpenBuilds(); return NavigationDecision.prevent; }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) async {
            final overall = widget.result.overallScore;
            final tier = widget.result.tierLabel;
            final subtitle = widget.result.tierSubtitle.replaceAll("'", "\\'");
            final bestScore = widget.result.bestScore;
            final d = widget.result.bestScoreDate;
            final dateText = "${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}";
            final repo = HeroRepository();
            final urls = <String>[];
            for (final p in widget.picks.take(5)) {
              String? u = p.imageUrl;
              if ((u==null || u.isEmpty) && p.heroId!=null && p.heroId!.isNotEmpty) {
                try { u = await repo.heroImageUrl(p.heroId!); } catch (_) {}
              }
              urls.add((u ?? '').replaceAll("'", "\\'"));
            }
            while (urls.length < 5) { urls.add(''); }
            final dataMap = {
              'genel': (widget.result.metrics[MetricTab.general] ?? const []).map((m) => {'title': m.title, 'score': m.score, 'desc': m.description}).toList(),
              'strateji': (widget.result.metrics[MetricTab.strategy] ?? const []).map((m) => {'title': m.title, 'score': m.score, 'desc': m.description}).toList(),
              'meta & zorluk': (widget.result.metrics[MetricTab.metaDifficulty] ?? const []).map((m) => {'title': m.title, 'score': m.score, 'desc': m.description}).toList(),
            };
            final dataJson = jsonEncode(dataMap).replaceAll('\\', '\\\\').replaceAll("'", "\\'");
            final sugsJson = jsonEncode(widget.result.suggestions.map((s)=>s.text).toList()).replaceAll('\\', '\\\\').replaceAll("'", "\\'");
            await _web?.runJavaScript("""
              (function(){
                const buttons = Array.from(document.querySelectorAll('button'));
                buttons.forEach(b=>{
                  const t=(b.innerText||'').trim().toLowerCase();
                  if(t.includes('yeni 5’li oluştur')){ b.addEventListener('click', ()=>{ window.location.href='bbml://new'; }); }
                  if(t.includes('tek kahraman değişt')){ b.addEventListener('click', ()=>{ window.location.href='bbml://replace'; }); }
                });
                const scoreEl = Array.from(document.querySelectorAll('p')).find(p=>p.textContent.trim()==='86');
                if(scoreEl) scoreEl.textContent = '$overall';
                const gauge = Array.from(document.querySelectorAll('path')).find(p=>p.getAttribute('stroke-dasharray') && p.getAttribute('stroke-dasharray').includes(','));
                if(gauge){ gauge.setAttribute('stroke-dasharray', `$overall, 100`); }
                const tierEl = Array.from(document.querySelectorAll('p')).find(p=>p.textContent.trim().toLowerCase().startsWith('tier'));
                if(tierEl) tierEl.textContent = '$tier';
                const subEl = Array.from(document.querySelectorAll('p')).find(p=>p.textContent.trim().includes('Rank için'));
                if(subEl) subEl.textContent = '$subtitle';
                const bestScoreEl = Array.from(document.querySelectorAll('p')).find(p=>p.textContent.trim()==='91');
                if(bestScoreEl) bestScoreEl.textContent = '$bestScore';
                const dateEl = Array.from(document.querySelectorAll('p')).find(p=>p.textContent.trim().match(/\\d{2}\\.\\d{2}\\.\\d{4}/));
                if(dateEl) dateEl.textContent = '$dateText';

                const avatarEls = Array.from(document.querySelectorAll('[data-alt]'));
                const urls = ['${urls[0]}','${urls[1]}','${urls[2]}','${urls[3]}','${urls[4]}'];
                avatarEls.slice(0,5).forEach((el, idx)=>{
                  const u = urls[idx];
                  if(u && u.length>0){ el.style.backgroundImage = "url('"+u+"')"; }
                });

                const data = JSON.parse('$dataJson');
                function render(items){
                  const container = document.querySelector('.flex.flex-col.gap-4.p-4');
                  if(!container) return;
                  container.innerHTML = items.map(it=>`
                    <div class="flex flex-col gap-3">
                      <div class="flex gap-6 justify-between">
                        <p class="text-black dark:text-white text-base font-medium leading-normal">\${it.title}</p>
                        <p class="text-black dark:text-white text-sm font-normal leading-normal">\${it.score}/100</p>
                      </div>
                      <div class="rounded-full bg-slate-200 dark:bg-slate-700">
                        <div class="h-2 rounded-full bg-primary" style="width: \${it.score}%;"></div>
                      </div>
                      <p class="text-slate-500 dark:text-slate-400 text-sm font-normal leading-normal">\${it.desc}</p>
                    </div>
                  `).join('');
                }
                const activeTab = Array.from(document.querySelectorAll('.pb-3.px-4 a')).find(a=>a.className.includes('border-b-primary'));
                let initialKey = 'genel';
                if(activeTab){
                  const t = activeTab.textContent.trim().toLowerCase();
                  initialKey = t.includes('genel') ? 'genel' : t.includes('strateji') ? 'strateji' : 'meta & zorluk';
                }
                render(data[initialKey]);
                try {
                  const sugs = JSON.parse('$sugsJson');
                  const h3 = Array.from(document.querySelectorAll('h3')).find(x=>x.textContent.trim().toLowerCase().includes('ai önerileri'));
                  const sec = h3 ? h3.parentElement : null;
                  const ul = sec ? sec.querySelector('ul') : null;
                  if(ul && Array.isArray(sugs)){
                    ul.innerHTML = sugs.map(s=>`<li class="text-sm text-slate-600 dark:text-slate-300">\${s}</li>`).join('');
                  }
                } catch(e){}
                const tabs = Array.from(document.querySelectorAll('.pb-3.px-4 a'));
                tabs.forEach(a=>{
                  a.addEventListener('click', (ev)=>{
                    ev.preventDefault();
                    const t = a.textContent.trim().toLowerCase();
                    const key = t.includes('genel') ? 'genel' : t.includes('strateji') ? 'strateji' : 'meta & zorluk';
                    render(data[key]);
                    tabs.forEach(x=>{
                      x.classList.remove('border-b-primary');
                      x.classList.add('border-b-transparent');
                      const p = x.querySelector('p');
                      if(p){
                        p.classList.remove('text-primary');
                        p.classList.add('text-slate-500');
                        p.classList.add('dark:text-slate-400');
                      }
                    });
                    a.classList.remove('border-b-transparent');
                    a.classList.add('border-b-primary');
                    const ap = a.querySelector('p');
                    if(ap){
                      ap.classList.remove('text-slate-500');
                      ap.classList.remove('dark:text-slate-400');
                      ap.classList.add('text-primary');
                    }
                  });
                });
              })();
            """);
          }
        ))
        ..loadHtmlString(tpl);
      setState(() => _web = c);
    });
  }
}
