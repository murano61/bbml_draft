import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../models/hero_model.dart';
import '../../models/search_log_model.dart';
import '../../services/hero_repository.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/primary_button.dart';

class EnemyPickScreen extends StatefulWidget {
  const EnemyPickScreen({super.key});

  @override
  State<EnemyPickScreen> createState() => _EnemyPickScreenState();
}

class _EnemyPickScreenState extends State<EnemyPickScreen> {
  final repo = HeroRepository();
  final TextEditingController _enemyCtrl = TextEditingController();
  HeroModel? _enemyHero;
  String? _role;
  final Set<String> _playStyle = {};

  final roles = const ['Gold', 'EXP', 'Jungle', 'Mid', 'Roam'];
  final styles = const ['Agresif', 'Güvenli', 'Takım Savaşı'];
  final Map<String, String> _imageUrls = {};

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  Future<void> _preloadImages() async {
    final heroes = repo.getHeroesLocal();
    for (final h in heroes) {
      final url = await repo.heroImageUrl(h.id);
      if (url != null && url.isNotEmpty) {
        _imageUrls[h.id] = url;
      }
    }
    if (mounted) setState(() {});
  }

  String _imageForHero(HeroModel h) {
    final cached = _imageUrls[h.id];
    if (cached != null && cached.isNotEmpty) return cached;
    switch (h.id) {
      case 'fanny':
        return 'https://lh3.googleusercontent.com/aida-public/AB6AXuBd1_eXFgWP28Yc5k7-bEAqDjI9H0iJQwY3J9FJVns4V3yNX3cp-tvV2ono9NpAGPkb_Q-hTacRyDS8IOwIIV1pxk0ZVPJtKOvgUPKtZmOx8c_MYjOkPBzW2685MRr1BcV0CjVFNaHrDWgpklMKMlnjiD-Kvuf37mZ5PIeQSTOMsLZzPzITmxcXZGWch5apx7N68h_le0GesA4fzMevFb4YIX1_lljiR3UvYHUC3MEzdwJAk2oarBuWQXOuGsFeDjGTJ05PW5BMb2TV';
      case 'miya':
        return 'https://via.placeholder.com/300x300.png?text=Miya';
      case 'tigreal':
        return 'https://via.placeholder.com/300x300.png?text=Tigreal';
      default:
        return 'https://via.placeholder.com/300x300.png?text=${h.name(context.locale.languageCode)}';
    }
  }

  void _submit() async {
    if (_enemyHero == null || _role == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('form_error_required'.tr())));
      return;
    }

    final suggestion = suggestHero(enemyHeroId: _enemyHero!.id, role: _role!, playStyle: _playStyle.toList());

    await repo.logSearch(SearchLog(
      type: 'enemy_pick',
      enemyHeroId: _enemyHero!.id,
      role: _role,
      playStyle: _playStyle.toList(),
      createdAt: DateTime.now(),
    ));

    if (!mounted) return;
    Navigator.pushNamed(context, K.routeEnemyPickResult, arguments: suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final heroes = repo.getHeroesLocal();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
        title: Text('enemy_pick_title'.tr()),
      ),
      body: Stack(children: [
        Positioned.fill(child: Container(color: AppColors.background)),
        Positioned.fill(child: IgnorePointer(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D0B1E), Colors.transparent, Color(0xFF0D0B1E)], begin: Alignment.bottomCenter, end: Alignment.topCenter))))),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Text('Choose Your Fighter!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              Center(child: Text('enemy_pick_subheader'.tr(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: heroes.map((h) {
                  final selected = _enemyHero?.id == h.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _enemyHero = h);
                      _enemyCtrl.text = h.name(context.locale.languageCode);
                    },
                    child: Stack(children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                          boxShadow: selected ? [const BoxShadow(color: AppColors.primary, blurRadius: 12, spreadRadius: 0)] : [],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(_imageForHero(h), fit: BoxFit.cover, errorBuilder: (context, error, stack) {
                            return Container(color: Colors.black26);
                          }),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                            child: Text(h.name(context.locale.languageCode), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              if (_enemyHero != null)
                Column(children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Column(children: [
                      CircleAvatar(radius: 36, backgroundColor: AppColors.primary, backgroundImage: NetworkImage(_imageForHero(_enemyHero!))),
                      const SizedBox(height: 8),
                      Text(_enemyHero!.name(context.locale.languageCode), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
              const SizedBox(height: 12),
              Text('Or Search Your Champion', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Autocomplete<HeroModel>(
                displayStringForOption: (h) => h.name(context.locale.languageCode),
                optionsBuilder: (text) {
                  final q = text.text.toLowerCase();
                  return heroes.where((h) => h.name(context.locale.languageCode).toLowerCase().contains(q));
                },
                onSelected: (h) {
                  setState(() => _enemyHero = h);
                  _enemyCtrl.text = h.name(context.locale.languageCode);
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(hintText: 'enemy_hero_hint'.tr(), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.card))));
                },
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: roles.map((r) {
                  final selected = _role == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PillChip(label: r, selected: selected, onTap: () => setState(() => _role = r)),
                  );
                }).toList()),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: styles.map((s) {
                  final selected = _playStyle.contains(s);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PillChip(label: s, selected: selected, onTap: () {
                      setState(() {
                        if (selected) {
                          _playStyle.remove(s);
                        } else {
                          _playStyle.add(s);
                        }
                      });
                    }),
                  );
                }).toList()),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'find_best_hero'.tr(), onPressed: _submit),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: null,
    );
  }
}

class HeroSuggestion {
  final HeroModel suggestedHero;
  final String difficulty;
  final String shortReason;
  final String earlyGamePlan;
  final String midGamePlan;
  final String lateGamePlan;
  final List<HeroModel> alternativeHeroes;
  const HeroSuggestion({
    required this.suggestedHero,
    required this.difficulty,
    required this.shortReason,
    required this.earlyGamePlan,
    required this.midGamePlan,
    required this.lateGamePlan,
    required this.alternativeHeroes,
  });
}

HeroSuggestion suggestHero({required String enemyHeroId, required String role, required List<String> playStyle}) {
  // Simple rule-set example for demo
  const heroes = sampleHeroes;
  if (enemyHeroId == 'fanny' && role.toLowerCase() == 'gold') {
    final miya = heroes.firstWhere((h) => h.id == 'miya');
    final tigreal = heroes.firstWhere((h) => h.id == 'tigreal');
    return HeroSuggestion(
      suggestedHero: miya,
      difficulty: 'Kolay',
      shortReason: 'reason_fanny_gold_miya_short'.tr(),
      earlyGamePlan: 'plan_early_miya_vs_fanny'.tr(),
      midGamePlan: 'plan_mid_miya_vs_fanny'.tr(),
      lateGamePlan: 'plan_late_miya_vs_fanny'.tr(),
      alternativeHeroes: [tigreal],
    );
  }

  final fallback = heroes.first;
  return HeroSuggestion(
    suggestedHero: fallback,
    difficulty: 'Orta',
    shortReason: 'generic_reason'.tr(),
    earlyGamePlan: 'generic_early'.tr(),
    midGamePlan: 'generic_mid'.tr(),
    lateGamePlan: 'generic_late'.tr(),
    alternativeHeroes: heroes.take(2).toList(),
  );
}
