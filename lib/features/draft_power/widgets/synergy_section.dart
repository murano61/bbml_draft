import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class SynergySection extends StatelessWidget {
  final List<SynergyMetricItem> items;
  const SynergySection({super.key, required this.items});
  Widget _bars(BuildContext context, int left, int right) {
    return LayoutBuilder(builder: (ctx, cons) {
      final lh = (left.clamp(0, 100)) / 100;
      final rh = (right.clamp(0, 100)) / 100;
      return Column(children: [
        Row(children: [
          Expanded(child: Container(
            height: 12,
            decoration: BoxDecoration(color: DraftColors.purpleLight.withValues(alpha: 0.25), borderRadius: const BorderRadius.only(topLeft: Radius.circular(999), bottomLeft: Radius.circular(999))),
            child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: lh, child: Container(decoration: const BoxDecoration(color: DraftColors.purple, borderRadius: BorderRadius.only(topLeft: Radius.circular(999), bottomLeft: Radius.circular(999)))))),
          )),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Container(
            height: 12,
            decoration: BoxDecoration(color: DraftColors.enemyRed.withValues(alpha: 0.25), borderRadius: const BorderRadius.only(topRight: Radius.circular(999), bottomRight: Radius.circular(999))),
            child: Align(alignment: Alignment.centerRight, child: FractionallySizedBox(widthFactor: rh, alignment: Alignment.centerRight, child: Container(decoration: const BoxDecoration(color: DraftColors.enemyRed, borderRadius: BorderRadius.only(topRight: Radius.circular(999), bottomRight: Radius.circular(999)))))),
          )),
        ]),
      ]);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Takım Uyumu', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...items.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DraftColors.textSecondary)),
            const SizedBox(height: 8),
            _bars(context, e.left, e.right),
          ]),
        )),
      ]),
    );
  }
}
