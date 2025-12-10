import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class TeamScoreCard extends StatelessWidget {
  final TeamScore score;
  final double leftPercent;
  const TeamScoreCard({super.key, required this.score, required this.leftPercent});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Senin Takımın – Rakip Takım', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${score.left}', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: DraftColors.green, fontWeight: FontWeight.w700))),
          Text('-', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: DraftColors.textSecondary)),
          Expanded(child: Align(alignment: Alignment.centerRight, child: Text('${score.right}', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: DraftColors.red, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 4,
          decoration: BoxDecoration(color: DraftColors.red, borderRadius: BorderRadius.circular(2)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: leftPercent / 100, child: Container(color: DraftColors.green)),
          ),
        ),
      ]),
    );
  }
}
