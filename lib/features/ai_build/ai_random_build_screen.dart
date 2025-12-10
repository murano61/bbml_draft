import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/item_api_service.dart';
import '../../services/build_api_service.dart';
import '../../models/build_model.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class AiRandomBuildScreen extends StatefulWidget {
  const AiRandomBuildScreen({super.key});
  @override
  State<AiRandomBuildScreen> createState() => _AiRandomBuildScreenState();
}

class _AiRandomBuildScreenState extends State<AiRandomBuildScreen> with SingleTickerProviderStateMixin {
  List<ItemModel> _items = [];
  late final ItemApiService _api;
  late final BuildApiService _buildApi;
  WebViewController? _web;
  @override
  void initState(){
    super.initState();
    _api = ItemApiService.create();
    _buildApi = BuildApiService.create();
    _generate();
  }
  Future<void> _generate() async {
    try {
      await _api.ensureCache();
      debugPrint('AiRandomBuildScreen -> fetching random build');
      final b = await _buildApi.getRandomBuild();
      if (b == null) {
        final all = await _buildApi.getAllBuilds();
        if (all.isNotEmpty) {
          final picked = all.first;
          _items = await _mapBuildItems(picked);
        }
      } else {
        _items = await _mapBuildItems(b);
      }
    } catch (_){ }
    if (!mounted) return;
    await _pushPayload();
  }
  Future<List<ItemModel>> _mapBuildItems(BuildModel b) async {
    final out = <ItemModel>[];
    if (b.itemsRaw.isNotEmpty) {
      for (final m in b.itemsRaw){ out.add(ItemModel.fromJson(m)); }
    } else if (b.itemIds.isNotEmpty) {
      for (final id in b.itemIds){ final it = await _api.getItemById(id) ?? ItemModel(id: id, name: 'Bulunamadı'); out.add(it); debugPrint('Random Build ${b.id} -> itemId=$id'); }
    }
    if (out.isEmpty) { final items = await _api.getAllItems(); return items.take(6).toList(); }
    return out.take(6).toList();
  }
  @override
  Widget build(BuildContext context){
    final c = WebViewController();
    c.setJavaScriptMode(JavaScriptMode.unrestricted);
    c.addJavaScriptChannel('BBML_BUILD', onMessageReceived: (m){ final v=m.message.toLowerCase(); if (v.contains('regen')) { _generate(); } });
    c.setNavigationDelegate(NavigationDelegate(onPageFinished: (url) async {
      final payload = {
        'items': _items.map((e)=> {'name': e.name, 'imageUrl': e.imageUrl}).toList(),
      };
      await c.runJavaScript('try{window.populate && populate(${jsonEncode(payload)});}catch(e){console.log("populate missing",e)}');
    }));
    Future(() async {
      try {
        final html = await rootBundle.loadString('assets/build_ai/random_build_1.html');
        await c.loadHtmlString(html);
      } catch (_) {
        debugPrint('AI Random Build asset not found in stable path');
        await c.loadHtmlString('<html><body style="background:#0D0B1E;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh">Asset not found</body></html>');
      }
    });
    _web = c;
    return Scaffold(appBar: AppBar(title: const Text('Rastgele Build Önerici')), body: WebViewWidget(controller: c));
  }
  Future<void> _pushPayload() async {
    if (_web == null) return;
    String? abs(String? url){
      if (url==null || url.isEmpty) return url;
      if (url.startsWith('http') || url.startsWith('data:')) return url;
      final p = url.startsWith('/') ? url : '/$url';
      return 'https://bbmlbuild.biz.tr$p';
    }
    final payload = { 'items': _items.map((e)=> {'name': e.name, 'imageUrl': abs(e.imageUrl)}).toList() };
    try { await _web!.runJavaScript('try{window.populate && populate(${jsonEncode(payload)});}catch(e){console.log("populate missing",e)}'); } catch (_) {}
  }
}
