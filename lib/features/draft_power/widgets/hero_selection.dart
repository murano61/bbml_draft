import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../colors.dart';
import '../../../services/hero_repository.dart';
import '../../../models/hero_model.dart';

class HeroSelection extends StatefulWidget {
  final Map<String, String> allyHeroes; // role -> heroId
  final Map<String, String> enemyHeroes; // role -> heroId
  final void Function(String role, String heroId, {required bool isAlly}) onPick;
  const HeroSelection({super.key, required this.allyHeroes, required this.enemyHeroes, required this.onPick});
  @override
  State<HeroSelection> createState() => _HeroSelectionState();
}

class _HeroSelectionState extends State<HeroSelection> {
  final List<String> _roles = const ['Gold', 'EXP', 'Mid', 'Jungle', 'Roam'];
  final Map<String, String> _ally = {};
  final Map<String, String> _enemy = {};

  @override
  void initState() {
    super.initState();
    _ally.addAll(widget.allyHeroes);
    _enemy.addAll(widget.enemyHeroes);
  }

  @override
  void didUpdateWidget(covariant HeroSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.allyHeroes, widget.allyHeroes)) {
      _ally
        ..clear()
        ..addAll(widget.allyHeroes);
    }
    if (!mapEquals(oldWidget.enemyHeroes, widget.enemyHeroes)) {
      _enemy
        ..clear()
        ..addAll(widget.enemyHeroes);
    }
  }

  Widget _avatar(String heroId, {Color border = DraftColors.green, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: border, width: 2)),
        child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/heroes/$heroId.png', width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: DraftColors.card))),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, {required bool isAlly, required String role}) async {
    final repo = HeroRepository();
    var heroes = await repo.getHeroesCached();
    if (heroes.isEmpty) heroes = await repo.getHeroes();
    String query = '';
    final locale = Localizations.localeOf(context).languageCode;
    String displayName(HeroModel h) => h.name(locale);
    String? result;
    await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: DraftColors.card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) {
      List<HeroModel> filtered = [...heroes];
      return StatefulBuilder(builder: (ctx, setSt) {
        filtered = query.isEmpty ? [...heroes] : heroes.where((h) => displayName(h).toLowerCase().contains(query.toLowerCase())).toList();
        filtered.sort((a,b)=> displayName(a).toLowerCase().compareTo(displayName(b).toLowerCase()));
        return SafeArea(child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(
                decoration: const InputDecoration(hintText: 'Hero seç veya ara…'),
                style: const TextStyle(color: DraftColors.textPrimary),
                onChanged: (v) => setSt(() { query = v; }),
              )),
            ]),
            const SizedBox(height: 12),
            Expanded(child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.72),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final h = filtered[i];
                return InkWell(
                  onTap: () { result = h.id; Navigator.pop(ctx); },
                  child: Column(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/heroes/${h.id}.png', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: DraftColors.card))),
                    const SizedBox(height: 6),
                    Text(displayName(h), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DraftColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(h.roles.isNotEmpty ? h.roles.join(', ') : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DraftColors.textSecondary, fontSize: 10)),
                  ]),
                );
              },
            )),
          ]),
        ));
      });
    });
    if (result != null) {
      setState(() {
        if (isAlly) {
          _ally[role] = result!;
        } else {
          _enemy[role] = result!;
        }
      });
      widget.onPick(role, result!, isAlly: isAlly);
    }
  }

  Widget _row(BuildContext context, String role, String allyId, String enemyId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Row(children: [
          _avatar((_ally[role] ?? allyId).isEmpty ? 'miya' : (_ally[role] ?? allyId), border: DraftColors.green, onTap: () => _openPicker(context, isAlly: true, role: role)),
          const SizedBox(width: 8),
          Text(role, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        ])),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(role, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          _avatar((_enemy[role] ?? enemyId).isEmpty ? 'moskov' : (_enemy[role] ?? enemyId), border: DraftColors.red, onTap: () => _openPicker(context, isAlly: false, role: role)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Kahraman Seçimi', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._roles.map((r) => _row(context, r, widget.allyHeroes[r] ?? '', widget.enemyHeroes[r] ?? '')),
      ]),
    );
  }
}
