import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/hero_model.dart';
import '../../models/counter_model.dart';
import '../../services/hero_repository.dart';
import '../../services/firebase_service.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/section_title.dart';
import '../../core/app_theme.dart';

class AdminCountersScreen extends StatefulWidget {
  const AdminCountersScreen({super.key});

  @override
  State<AdminCountersScreen> createState() => _AdminCountersScreenState();
}

class _AdminCountersScreenState extends State<AdminCountersScreen> {
  final repo = HeroRepository();
  final _mainCtrl = TextEditingController();
  final List<_CounterForm> _formsCounters = List.generate(5, (_) => _CounterForm());
  final List<_CounterForm> _formsCountered = List.generate(5, (_) => _CounterForm());
  List<HeroModel> _heroes = [];
  CountersDoc? _preview;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHeroes();
  }

  Future<void> _loadHeroes() async {
    _heroes = await repo.getHeroes();
    if (mounted) setState(() {});
  }

  Future<void> _saveCounters() async {
    final mainId = _mainCtrl.text.trim();
    if (mainId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ana kahraman ID gerekli')));
      return;
    }
    final counters = _formsCounters
        .where((f) => f.heroCtrl.text.trim().isNotEmpty)
        .map((f) => {
              'heroId': f.heroCtrl.text.trim(),
              'difficulty': f.difficulty.toLowerCase(),
              'reason_tr': f.reasonCtrl.text.trim(),
              'reason_en': f.reasonCtrl.text.trim(),
              'reason_ru': f.reasonCtrl.text.trim(),
              'reason_id': f.reasonCtrl.text.trim(),
              'reason_fil': f.reasonCtrl.text.trim(),
            })
        .toList();
    try {
      await FirebaseService.db.collection('counters').doc(mainId).set({'counters': counters}, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karşılaştığı En İyi Counterlar kaydedildi')));
      await _refreshPreview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme hatası')));
    }
  }

  Future<void> _saveCountered() async {
    final mainId = _mainCtrl.text.trim();
    if (mainId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ana kahraman ID gerekli')));
      return;
    }
    final countered = _formsCountered
        .where((f) => f.heroCtrl.text.trim().isNotEmpty)
        .map((f) => {
              'heroId': f.heroCtrl.text.trim(),
              'difficulty': f.difficulty.toLowerCase(),
              'reason_tr': f.reasonCtrl.text.trim(),
              'reason_en': f.reasonCtrl.text.trim(),
              'reason_ru': f.reasonCtrl.text.trim(),
              'reason_id': f.reasonCtrl.text.trim(),
              'reason_fil': f.reasonCtrl.text.trim(),
            })
        .toList();
    try {
      await FirebaseService.db.collection('counters').doc(mainId).set({'countered': countered}, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En Çok Counterladığı Herolar kaydedildi')));
      await _refreshPreview();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme hatası')));
    }
  }

  Future<void> _refreshPreview() async {
    final id = _mainCtrl.text.trim();
    if (id.isEmpty) return;
    _preview = await repo.countersFor(id, context.locale.languageCode);
    _populateFormsFromPreview();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    for (final f in _formsCounters) {
      f.heroCtrl.dispose();
      f.reasonCtrl.dispose();
    }
    for (final f in _formsCountered) {
      f.heroCtrl.dispose();
      f.reasonCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroes = _heroes;
    return Scaffold(
      appBar: AppBar(title: Text('admin_counters_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title: 'admin_counters_title'.tr(), subtitle: 'admin_counters_desc'.tr()),
            const SizedBox(height: 12),
            Autocomplete<HeroModel>(
              displayStringForOption: (h) => h.name(context.locale.languageCode),
              optionsBuilder: (text) {
                final q = text.text.toLowerCase();
                return heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
              },
              onSelected: (h) {
                _mainCtrl.text = h.id;
                _refreshPreview();
              },
              fieldViewBuilder: (context2, controller, focusNode, onFieldSubmitted) {
                controller.text = _mainCtrl.text;
                controller.addListener(() { _mainCtrl.text = controller.text; });
                return TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: 'Ana Kahraman (main)'));
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _segButton(label: 'best_counters_title'.tr(), selected: _tabIndex == 0, onTap: () { setState(() { _tabIndex = 0; }); })),
              const SizedBox(width: 8),
              Expanded(child: _segButton(label: 'most_countered_title'.tr(), selected: _tabIndex == 1, onTap: () { setState(() { _tabIndex = 1; }); })),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(_tabIndex == 0 ? 'best_counters_title'.tr() : 'most_countered_title'.tr(), style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {
                setState(() {
                  final list = _tabIndex == 0 ? _formsCounters : _formsCountered;
                  for (final f in list) { f.heroCtrl.clear(); f.reasonCtrl.clear(); f.difficulty = 'Orta'; }
                });
              }, child: const Text('Temizle')),
            ]),
            const SizedBox(height: 8),
            ...List.generate((_tabIndex == 0 ? _formsCounters.length : _formsCountered.length), (i) {
              final f = _tabIndex == 0 ? _formsCounters[i] : _formsCountered[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(children: [
                  Expanded(flex: 2, child: Autocomplete<HeroModel>(
                    displayStringForOption: (h) => h.name(context.locale.languageCode),
                    optionsBuilder: (text) {
                      final q = text.text.toLowerCase();
                      return heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
                    },
                    onSelected: (h) { f.heroCtrl.text = h.id; },
                    fieldViewBuilder: (context2, controller, focusNode, onFieldSubmitted) {
                      controller.text = f.heroCtrl.text;
                      controller.addListener(() { f.heroCtrl.text = controller.text; });
                      return TextField(controller: controller, focusNode: focusNode, decoration: InputDecoration(labelText: 'Öneri ${i+1} - Kahraman'));
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(controller: f.reasonCtrl, decoration: const InputDecoration(labelText: 'Kısa açıklama'))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: f.difficulty,
                    items: const [
                      DropdownMenuItem(value: 'Kolay', child: Text('Kolay')),
                      DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                      DropdownMenuItem(value: 'Zor', child: Text('Zor')),
                    ],
                    onChanged: (v) { setState(() { f.difficulty = v ?? 'Orta'; }); },
                  ),
                ]),
              );
            }),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _saveCounters, child: const Text('Karşılaştığı En İyi Counterları Kaydet'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: _saveCountered, child: const Text('En Çok Counterladığı Heroları Kaydet'))),
            ]),
            const SizedBox(height: 24),
            if (_preview != null) ...[
              SectionTitle(title: 'best_counters_title'.tr()),
              const SizedBox(height: 8),
              ..._bestCounters().map((c) {
                final hero = heroes.firstWhere((h) => h.id == c.heroId, orElse: () => HeroModel(id: c.heroId, names: {'en': c.heroId}, roles: const ['Unknown']));
                final reason = c.reason[context.locale.languageCode] ?? c.reason['en'] ?? '';
                final badge = c.difficulty == 'hard' ? 'Zor' : c.difficulty == 'medium' ? 'Orta' : 'Kolay';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: HeroCard(hero: hero, subtitle: reason, badge: badge),
                );
              }),
              const SizedBox(height: 16),
              SectionTitle(title: 'most_countered_title'.tr()),
              const SizedBox(height: 8),
              ...(_preview?.countered ?? []).map((c) {
                final hero = heroes.firstWhere((h) => h.id == c.heroId, orElse: () => HeroModel(id: c.heroId, names: {'en': c.heroId}, roles: const ['Unknown']));
                final reason = c.reason[context.locale.languageCode] ?? c.reason['en'] ?? '';
                final badge = c.difficulty == 'hard' ? 'Zor' : c.difficulty == 'medium' ? 'Orta' : 'Kolay';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: HeroCard(hero: hero, subtitle: reason, badge: badge),
                );
              }),
            ],
          ]),
        ),
      ),
    );
  }

  List<CounterEntry> _bestCounters() {
    final list = _preview?.counters ?? [];
    final hard = list.where((c) => c.difficulty.toLowerCase() == 'hard').toList();
    if (hard.isNotEmpty) return hard.take(3).toList();
    final medium = list.where((c) => c.difficulty.toLowerCase() == 'medium').toList();
    return medium.take(3).toList();
  }

  Widget _segButton({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 40,
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.card, borderRadius: BorderRadius.circular(24)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _populateFormsFromPreview() {
    final counters = _preview?.counters ?? const <CounterEntry>[];
    final countered = _preview?.countered ?? const <CounterEntry>[];
    for (var i = 0; i < _formsCounters.length; i++) {
      final f = _formsCounters[i];
      if (i < counters.length) {
        final c = counters[i];
        f.heroCtrl.text = c.heroId;
        f.reasonCtrl.text = c.reason[context.locale.languageCode] ?? c.reason['en'] ?? '';
        final diff = c.difficulty.toLowerCase();
        f.difficulty = diff == 'easy' ? 'Kolay' : diff == 'hard' ? 'Zor' : 'Orta';
      } else {
        f.heroCtrl.clear();
        f.reasonCtrl.clear();
        f.difficulty = 'Orta';
      }
    }
    for (var i = 0; i < _formsCountered.length; i++) {
      final f = _formsCountered[i];
      if (i < countered.length) {
        final c = countered[i];
        f.heroCtrl.text = c.heroId;
        f.reasonCtrl.text = c.reason[context.locale.languageCode] ?? c.reason['en'] ?? '';
        final diff = c.difficulty.toLowerCase();
        f.difficulty = diff == 'easy' ? 'Kolay' : diff == 'hard' ? 'Zor' : 'Orta';
      } else {
        f.heroCtrl.clear();
        f.reasonCtrl.clear();
        f.difficulty = 'Orta';
      }
    }
  }
}

class _CounterForm {
  final TextEditingController heroCtrl = TextEditingController();
  final TextEditingController reasonCtrl = TextEditingController();
  String difficulty = 'Orta';
}
