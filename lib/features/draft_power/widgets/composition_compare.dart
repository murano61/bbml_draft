import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class CompositionCompare extends StatelessWidget {
  final List<String> allyItems;
  final List<String> enemyItems;
  final List<CompositionAspectItem> aspects;
  const CompositionCompare({super.key, required this.allyItems, required this.enemyItems, required this.aspects});
  Widget _list(List<String> items, Color accent, {bool good = true}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent, width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Icon(good ? Icons.check : Icons.close, size: 16, color: good ? DraftColors.green : DraftColors.red),
        const SizedBox(width: 6),
        Expanded(child: Text(e, style: const TextStyle(color: DraftColors.textSecondary))),
      ]))).toList()),
    );
  }
  Widget _aspect(CompositionAspectItem it) {
    return Column(children: [
      Text(it.name, style: const TextStyle(color: DraftColors.textSecondary)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: it.left/100, minHeight: 10, color: DraftColors.green, backgroundColor: DraftColors.green.withValues(alpha: 0.25))))
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: it.right/100, minHeight: 10, color: DraftColors.red, backgroundColor: DraftColors.red.withValues(alpha: 0.25))))
      ])
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('5v5 Kompozisyon Karşılaştırması', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(children: [
            const Text('Senin Takımın', style: TextStyle(color: DraftColors.green, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _list(allyItems, DraftColors.green, good: true),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [
            const Text('Rakip Takım', style: TextStyle(color: DraftColors.red, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _list(enemyItems, DraftColors.red, good: false),
          ])),
        ]),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.6),
          itemCount: aspects.length,
          itemBuilder: (_, i) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: DraftColors.purple, width: 1.1)), child: _aspect(aspects[i])),
        )
      ]),
    );
  }
}
