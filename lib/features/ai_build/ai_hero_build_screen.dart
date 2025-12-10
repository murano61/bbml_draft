import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/item_api_service.dart';
import '../../services/build_api_service.dart';
import '../../models/build_model.dart';

class AiHeroBuildScreen extends StatefulWidget {
  final Map<String, dynamic>? hero;
  const AiHeroBuildScreen({super.key, required this.hero});
  @override
  State<AiHeroBuildScreen> createState() => _AiHeroBuildScreenState();
}

class _AiHeroBuildScreenState extends State<AiHeroBuildScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<ItemModel> _meta = [];
  List<ItemModel> _fun = [];
  String _spell = '';
  String _emblem = '';
  late final ItemApiService _api;
  late final BuildApiService _buildApi;
  WebViewController? _web;
  bool _computed = false;
  bool _fallbackPushed = false;
  @override
  void initState(){
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _api = ItemApiService.create();
    _buildApi = BuildApiService.create();
    _generate();
  }
  Future<void> _generate() async {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      await _api.ensureCache();
      final items = await _api.getAllItems();
      final hero = widget.hero ?? {};
      final heroName = (hero['name'] ?? '') as String;
      final role = (hero['role'] ?? '') as String;
      debugPrint('AiBuildHeroScreen -> fetching builds for heroName=$heroName');
      final heroId = (hero['id'] ?? '').toString();
      final builds = await _buildApi.getBuildsByHero(heroId: heroId.isNotEmpty ? heroId : null, heroName: heroName);
      String spell = '';
      String emblem = '';
      List<BuildModel> metaBuilds = builds.where((b) => b.type.toLowerCase()=='meta').toList();
      List<BuildModel> funBuilds = builds.where((b) => b.type.toLowerCase()!='meta').toList();
      if (metaBuilds.isEmpty && builds.isNotEmpty) { metaBuilds = [builds.first]; }
      if (funBuilds.isEmpty && builds.length>1) { funBuilds = [builds[1]]; }
      Future<List<ItemModel>> mapItems(BuildModel b) async {
        final out = <ItemModel>[];
        if (b.itemsRaw.isNotEmpty) {
          for (final m in b.itemsRaw){
            final it = ItemModel.fromJson(m);
            out.add(it);
          }
        } else if (b.itemIds.isNotEmpty) {
          for (final id in b.itemIds){
            final it = await _api.getItemById(id) ?? ItemModel(id: id, name: 'Bulunamadı');
            out.add(it);
            debugPrint('Build ${b.id} -> itemId=$id');
          }
        }
        return out;
      }
      _meta = metaBuilds.isNotEmpty ? await mapItems(metaBuilds.first) : [];
      _fun = funBuilds.isNotEmpty ? await mapItems(funBuilds.first) : [];
      spell = metaBuilds.isNotEmpty ? (metaBuilds.first.spell ?? '') : '';
      emblem = metaBuilds.isNotEmpty ? (metaBuilds.first.emblem ?? '') : '';
      if (_meta.isEmpty) {
        _meta = items.where((e)=> (e.imageUrl??'').isNotEmpty).take(6).toList();
      }
      if (_fun.isEmpty) {
        final rem = items.where((e)=> (e.imageUrl??'').isNotEmpty && !_meta.any((m)=> m.id==e.id)).take(6).toList();
        _fun = rem.isNotEmpty ? rem : items.take(6).toList();
      }
      _spell = spell;
      _emblem = emblem;
      if (!_api.apiOk || builds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Build bilgileri alınamadı, lütfen daha sonra tekrar deneyin.')));
        }
      }
    } catch (_) {}
    if (!mounted) return;
    _computed = true;
    if (_web != null) {
      await _pushPayload();
    }
  }
  @override
  void dispose(){ _tab.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context){
    final hero = widget.hero ?? {};
    final name = (hero['name'] ?? '') as String;
    final img = (hero['imageUrl'] ?? '') as String;
    final role = (hero['role'] ?? '') as String;
    final c = WebViewController();
    c.setJavaScriptMode(JavaScriptMode.unrestricted);
    c.addJavaScriptChannel('BBML_BUILD', onMessageReceived: (m){ final v=m.message.toLowerCase(); if (v.contains('regen')) { _generate(); } });
    c.setNavigationDelegate(NavigationDelegate(onPageFinished: (url) async {
        final payload = _buildPayload(name: name, role: role, img: img);
        final js = 'try{window.populate && populate(${jsonEncode(payload)});}catch(e){console.log("populate missing",e);}';
        await c.runJavaScript(js);
      }));
    Future(() async {
      try {
        final html = await rootBundle.loadString('assets/build_ai/hero_build_2.html');
        await c.loadHtmlString(html);
      } catch (_) {
        debugPrint('AI Hero Build result asset not found');
      }
    });
    _web = c;
    if (_computed) { Future.microtask(() => _pushPayload()); }
    _scheduleFallback();
    return Scaffold(appBar: AppBar(title: const Text('AI Build')), body: WebViewWidget(controller: c));
  }
  void _scheduleFallback(){
    if (_fallbackPushed) return;
    Future.delayed(const Duration(seconds: 2), () async {
      if (!_computed) {
        try {
          await _api.ensureCache();
          final items = await _api.getAllItems();
          if (_meta.isEmpty) { _meta = items.where((e)=> (e.imageUrl??'').isNotEmpty).take(6).toList(); }
          if (_fun.isEmpty) {
            final rem = items.where((e)=> (e.imageUrl??'').isNotEmpty && !_meta.any((m)=> m.id==e.id)).take(6).toList();
            _fun = rem.isNotEmpty ? rem : items.take(6).toList();
          }
          _spell = _spell.isNotEmpty ? _spell : 'Retribution';
          _emblem = _emblem.isNotEmpty ? _emblem : 'Orman Amblemi';
          _fallbackPushed = true;
          await _pushPayload();
        } catch (_) {}
      }
    });
  }
  Future<void> _pushPayload() async {
    if (_web == null) return;
    try {
      final html = await rootBundle.loadString('assets/build_ai/hero_build_2.html');
      await _web!.loadHtmlString(html);
    } catch (_) { debugPrint('Failed to load hero_build_2.html'); }
    await Future.delayed(const Duration(milliseconds: 250));
    final hero = widget.hero ?? {};
    final name = (hero['name'] ?? '') as String;
    final img = (hero['imageUrl'] ?? '') as String;
    final role = (hero['role'] ?? '') as String;
    final payload = _buildPayload(name: name, role: role, img: img);
    try { await _web!.runJavaScript('try{window.populate && populate(${jsonEncode(payload)});}catch(e){console.log("populate missing",e)}'); } catch (_) { debugPrint('populate JS failed'); }
  }

  Map<String, dynamic> _buildPayload({required String name, required String role, required String img}){
    Map<String, dynamic> itemToMap(ItemModel e){
      String? imgUrl = e.imageUrl;
      if (imgUrl != null && imgUrl.isNotEmpty && !imgUrl.startsWith('http') && !imgUrl.startsWith('data:')){
        final p = imgUrl.startsWith('/') ? imgUrl : '/$imgUrl';
        imgUrl = 'https://bbmlbuild.biz.tr$p';
      }
      final desc = (e.id==0) ? 'Bu item API\'de bulunamadı' : (e.shortDescription ?? e.description ?? '');
      return {'name': e.name, 'imageUrl': imgUrl, 'desc': desc};
    }
    return {
      'hero': {'name': name, 'role': role, 'imageUrl': img},
      'meta': _meta.map(itemToMap).toList(),
      'fun': _fun.map(itemToMap).toList(),
      'spell': _spell,
      'emblem': _emblem,
    };
  }
}
