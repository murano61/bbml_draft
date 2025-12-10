import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/hero_repository.dart';
import '../../models/hero_model.dart';
import 'ai_hero_build_screen.dart';

class AiHeroSelectScreen extends StatefulWidget {
  const AiHeroSelectScreen({super.key});
  @override
  State<AiHeroSelectScreen> createState() => _AiHeroSelectScreenState();
}

class _AiHeroSelectScreenState extends State<AiHeroSelectScreen> {
  List<HeroModel> _heroes = const [];
  String _query = '';
  String _lane = 'all';
  HeroModel? _selected;
  bool _loading = true;
  @override
  void initState(){
    super.initState();
    _load();
  }
  Future<void> _load() async {
    var heroes = await HeroRepository().getHeroesCached();
    if (heroes.isEmpty) heroes = await HeroRepository().getHeroes();
    if (!mounted) return;
    setState(() { _heroes = heroes; _loading = false; });
  }
  List<HeroModel> _filtered(){
    Iterable<HeroModel> base = _heroes;
    if (_lane != 'all') {
      final lk = _lane.toLowerCase();
      base = base.where((h) => h.lanes.map((x)=>x.toLowerCase()).contains(lk));
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      base = base.where((h)=> h.name(Localizations.localeOf(context).languageCode).toLowerCase().contains(q) || h.name('en').toLowerCase().contains(q));
    }
    return base.toList();
  }
  void _confirm(){
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen önce bir kahraman seç')));
      return;
    }
    final hero = _selected!;
    final locale = Localizations.localeOf(context).languageCode;
    debugPrint('Hero selected for AI Build: ${hero.name(locale)} (${hero.id})');
    final data = {
      'id': hero.id,
      'name': hero.name(locale),
      'role': (hero.roles.isNotEmpty ? hero.roles.first : (hero.lanes.isNotEmpty ? hero.lanes.first : '')),
      'imageUrl': hero.imageUrl,
    };
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiHeroBuildScreen(hero: data)),
    );
  }
  @override
  Widget build(BuildContext context){
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: const Text('Kahraman Seç')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children:[
          TextField(
            decoration: const InputDecoration(hintText: 'Kahraman ara…'),
            onChanged: (v)=> setState(()=> _query=v),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children:[
            for (final k in ['all','exp','jungle','mid','gold']) ChoiceChip(
              label: Text(k=='all'? 'Tümü':'${k[0].toUpperCase()}${k.substring(1)}'),
              selected: _lane==k,
              onSelected: (_)=> setState(()=> _lane=k),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8),
            itemCount: _filtered().length,
            itemBuilder: (_, i){
              final h = _filtered()[i];
              final selected = _selected?.id == h.id;
              final url = h.imageUrl;
              return InkWell(
                onTap: () => setState(()=> _selected = h),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? AppColors.primaryNeon : AppColors.accentPink, width: selected? 2 : 1.2),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(children:[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: url!=null && url.isNotEmpty ? Image.network(
                        url,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width:60, height:60, color: AppColors.card),
                      ) : Container(width:60, height:60, color: AppColors.card),
                    ),
                    const SizedBox(height: 6),
                    Text(h.name(locale), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: const Text('Seçimi Onayla')),
          ),
        ]),
      ),
    );
  }
}
