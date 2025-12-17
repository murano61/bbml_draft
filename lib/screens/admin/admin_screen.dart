import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../core/constants.dart';
import '../../services/hero_repository.dart';
import '../../models/hero_model.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final Set<String> _roles = {};
  final Set<String> _lanes = {};
  final _counterMainCtrl = TextEditingController();
  final List<_CounterEntryForm> _counterForms = [
    _CounterEntryForm(),
    _CounterEntryForm(),
    _CounterEntryForm(),
    _CounterEntryForm(),
    _CounterEntryForm(),
  ];
  final repo = HeroRepository();
  List<HeroModel> _heroes = [];

  final List<String> _roleOptions = const ['Tank', 'Assassin', 'Marksman', 'Mage', 'Support', 'Fighter'];
  final List<String> _laneOptions = const ['Gold', 'EXP', 'Jungle', 'Mid', 'Roam'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _idCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final data = {
      'id': id,
      'name_tr': name,
      'name_en': name,
      'name_ru': name,
      'name_id': name,
      'name_fil': name,
      'roles': _roles.toList(),
      'lanes': _lanes.toList(),
      'imageUrl': _imageUrlCtrl.text.trim(),
    };
    await FirebaseService.db.collection('heroes').doc(id).set(data, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  Future<void> _deleteHero(String id) async {
    try {
      await FirebaseService.db.collection('heroes').doc(id).delete();
      await FirebaseService.db.collection('hero_stats').doc(id).delete();
      await FirebaseService.db.collection('counters').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silindi: $id')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silme hatası')));
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _imageUrlCtrl.dispose();
    _counterMainCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadHeroes();
  }

  Future<void> _loadHeroes() async {
    final cached = await repo.getHeroesCached();
    _heroes = cached;
    if (mounted) setState(() {});
    final fresh = await repo.getHeroes();
    if (fresh.isNotEmpty) {
      _heroes = fresh;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Counter yönetimi sayfası bu sürümde yok; butonu gizledik
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'ID'), validator: (v) => (v==null||v.trim().isEmpty)?'Gerekli':null),
                  const SizedBox(height: 8),
                  TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Ad')),
                  const SizedBox(height: 8),
                  TextFormField(controller: _imageUrlCtrl, decoration: const InputDecoration(labelText: 'Resim URL')),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: _roleOptions.map((r) {
                    final selected = _roles.contains(r);
                    return FilterChip(
                      label: Text(r),
                      selected: selected,
                      onSelected: (s) {
                        setState(() {
                          if (s) { _roles.add(r); } else { _roles.remove(r); }
                        });
                      },
                    );
                  }).toList()),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: _laneOptions.map((r) {
                    final selected = _lanes.contains(r);
                    return FilterChip(
                      label: Text(r),
                      selected: selected,
                      onSelected: (s) {
                        setState(() {
                          if (s) { _lanes.add(r); } else { _lanes.remove(r); }
                        });
                      },
                    );
                  }).toList()),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('Kaydet'))),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('Kahramanlar'),
              const SizedBox(height: 8),
              SizedBox(
                height: 400,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseService.db.collection('heroes').orderBy(FieldPath.fromString('id'), descending: false).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) { return const Text('Hata'); }
                    if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Text('Veri yok');
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        return ListTile(
                          title: Text(d['id'] ?? ''),
                          subtitle: Text((d['name_tr'] ?? d['name_en'] ?? '') as String),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('R: ${(((d['roles'] ?? []) as List).join(', '))}'),
                            const SizedBox(width: 8),
                            Text('L: ${(((d['lanes'] ?? []) as List).join(', '))}'),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteHero((d['id'] ?? docs[i].id) as String)),
                          ]),
                          onTap: () {
                            _idCtrl.text = (d['id'] ?? '') as String;
                            _nameCtrl.text = ((d['name_tr'] ?? d['name_en'] ?? d['name_ru'] ?? d['name_id'] ?? d['name_fil']) ?? '') as String;
                            _imageUrlCtrl.text = (d['imageUrl'] ?? '') as String;
                            final roles = List<String>.from(d['roles'] ?? []);
                            setState(() { _roles
                              ..clear()
                              ..addAll(roles);
                            });
                            final lanes = List<String>.from(d['lanes'] ?? []);
                            setState(() { _lanes
                              ..clear()
                              ..addAll(lanes);
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Öneriler (Bir kahramana 5 öneri)'),
              const SizedBox(height: 8),
              Autocomplete<HeroModel>(
                displayStringForOption: (h) => h.name(context.locale.languageCode),
                optionsBuilder: (text) {
                  final q = text.text.toLowerCase();
                  return _heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
                },
                onSelected: (h) { _counterMainCtrl.text = h.id; },
                fieldViewBuilder: (context2, controller, focusNode, onFieldSubmitted) {
                  controller.text = _counterMainCtrl.text;
                  controller.addListener(() { _counterMainCtrl.text = controller.text; });
                  return TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: 'Ana Kahraman (rakip)')); 
                },
              ),
              const SizedBox(height: 8),
              ...List.generate(_counterForms.length, (i) {
                final f = _counterForms[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(children: [
                    Expanded(flex: 2, child: Autocomplete<HeroModel>(
                      displayStringForOption: (h) => h.name(context.locale.languageCode),
                      optionsBuilder: (text) {
                        final q = text.text.toLowerCase();
                        return _heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
                      },
                      onSelected: (h) { f.heroCtrl.text = h.id; },
                      fieldViewBuilder: (context2, controller, focusNode, onFieldSubmitted) {
                        controller.text = f.heroCtrl.text;
                        controller.addListener(() { f.heroCtrl.text = controller.text; });
                        return TextField(controller: controller, focusNode: focusNode, decoration: InputDecoration(labelText: 'Öneri ${i+1} - Kahraman')); 
                      },
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(controller: f.reasonCtrl, decoration: const InputDecoration(labelText: 'Kısa açıklama')),
                    ),
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
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveCounters, child: const Text('Önerileri Kaydet'))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCounters() async {
    final mainId = _counterMainCtrl.text.trim();
    if (mainId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ana kahraman ID gerekli')));
      return;
    }
    final counters = _counterForms
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Öneriler kaydedildi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydetme hatası')));
    }
  }
}

class _CounterEntryForm {
  final TextEditingController heroCtrl = TextEditingController();
  final TextEditingController reasonCtrl = TextEditingController();
  String difficulty = 'Orta';
}
