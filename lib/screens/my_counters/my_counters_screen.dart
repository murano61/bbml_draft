import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/hero_model.dart';
import '../../models/counter_model.dart';
import '../../models/search_log_model.dart';
import '../../services/hero_repository.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/primary_button.dart';

class MyCountersScreen extends StatefulWidget {
  const MyCountersScreen({super.key});

  @override
  State<MyCountersScreen> createState() => _MyCountersScreenState();
}

class _MyCountersScreenState extends State<MyCountersScreen> {
  final repo = HeroRepository();
  HeroModel? _mainHero;
  final roles = const ['Tank', 'Fighter', 'Assassin', 'Mage', 'Marksman', 'Support'];
  final Set<String> _roleFilters = {};
  List<CounterEntry> _results = [];

  void _submit() async {
    if (_mainHero == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('form_error_required'.tr())));
      return;
    }
    final doc = await repo.countersFor(_mainHero!.id, context.locale.languageCode);
    setState(() {
      _results = (doc?.counters ?? [])
          .where((c) => _roleFilters.isEmpty || _roleFilters.contains(_roleFromHeroId(c.heroId)))
          .toList();
    });

    await repo.logSearch(SearchLog(
      type: 'my_counters',
      mainHeroId: _mainHero!.id,
      createdAt: DateTime.now(),
    ));
  }

  String _roleFromHeroId(String heroId) {
    final heroes = repo.getHeroesLocal();
    return heroes.firstWhere((h) => h.id == heroId).roles.first;
  }

  @override
  Widget build(BuildContext context) {
    final heroes = repo.getHeroesLocal();
    return Scaffold(
      appBar: AppBar(title: Text('my_counters_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('my_counters_header'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('my_counters_subheader'.tr()),
          const SizedBox(height: 16),
          Autocomplete<HeroModel>(
            displayStringForOption: (h) => h.name(context.locale.languageCode),
            optionsBuilder: (text) {
              final q = text.text.toLowerCase();
              return heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
            },
            onSelected: (h) => setState(() => _mainHero = h),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(hintText: 'enemy_hero_hint'.tr()),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: roles.map((r) {
            final selected = _roleFilters.contains(r);
            return PillChip(label: r, selected: selected, onTap: () {
              setState(() {
                if (selected) {
                  _roleFilters.remove(r);
                } else {
                  _roleFilters.add(r);
                }
              });
            });
          }).toList()),
          const SizedBox(height: 16),
          PrimaryButton(label: 'show_counters'.tr(), onPressed: _submit),
          const SizedBox(height: 16),
          if (_results.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Text('empty_state_stats'.tr()),
            )
          else ...[
            ..._results.map((c) {
              final hero = heroes.firstWhere((h) => h.id == c.heroId);
              final reason = c.reason[context.locale.languageCode] ?? c.reason['en'] ?? '';
              final badge = switch (c.difficulty) {
                'easy' => 'Kolay',
                'medium' => 'Orta',
                'hard' => 'Zor',
                _ => c.difficulty,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: HeroCard(hero: hero, subtitle: reason, badge: badge),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.lightbulb, color: AppColors.accentPurple), const SizedBox(width: 8), Text('tactics_for_matchup'.tr())]),
                const SizedBox(height: 8),
                _bullet('tip_ulti_timing'.tr()),
                _bullet('tip_def_items'.tr()),
                _bullet('tip_map_position'.tr()),
              ]),
            ),
          ],
        ]),
      ),
      bottomNavigationBar: null,
    );
  }

  Widget _bullet(String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.circle, size: 8),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ]);
  }
}
