import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class LaneMatchupCard extends StatelessWidget {
  final LaneMatchup data;
  const LaneMatchupCard({super.key, required this.data});
  Widget _avatar(String id) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: DraftColors.purple, width: 2)),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/heroes/$id.png', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: DraftColors.card))),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.lane, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _avatar(data.allyHeroId),
          const SizedBox(width: 8),
          Expanded(child: Center(child: RichText(text: TextSpan(children: [
            TextSpan(text: '${data.leftScore}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DraftColors.green, fontWeight: FontWeight.w700)),
            TextSpan(text: ' - ', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DraftColors.textPrimary)),
            TextSpan(text: '${data.rightScore}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DraftColors.red, fontWeight: FontWeight.w700)),
          ])))) ,
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: DraftColors.red, width: 2)),
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/heroes/${data.enemyHeroId}.png', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: DraftColors.card))),
          ),
        ]),
        const SizedBox(height: 8),
        Text(data.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DraftColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          height: 4,
          decoration: BoxDecoration(color: DraftColors.red, borderRadius: BorderRadius.circular(2)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: (data.leftScore.clamp(0, 100)) / 100, child: Container(color: DraftColors.green)),
          ),
        ),
      ]),
    );
  }
}
