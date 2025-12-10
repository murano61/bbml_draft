import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class MetaSection extends StatelessWidget {
  final MetaScores scores;
  const MetaSection({super.key, required this.scores});
  Widget _circle(int value, Color color, String label) {
    return Column(children: [
      SizedBox(
        width: 72,
        height: 72,
        child: Stack(children: [
          Center(child: Text('$value', style: const TextStyle(color: DraftColors.textPrimary, fontWeight: FontWeight.w700))),
          CircularProgressIndicator(value: value/100, strokeWidth: 6, color: color, backgroundColor: color.withValues(alpha: 0.25)),
        ]),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: DraftColors.textSecondary))
    ]);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Meta Uygunluğu', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(children: [const Text('Senin takımın', style: TextStyle(color: DraftColors.textSecondary)), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: scores.ally/100, minHeight: 12, color: DraftColors.green, backgroundColor: DraftColors.green.withValues(alpha: 0.25)))])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [const Text('Rakip takım', style: TextStyle(color: DraftColors.textSecondary)), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: scores.enemy/100, minHeight: 12, color: DraftColors.red, backgroundColor: DraftColors.red.withValues(alpha: 0.25)))])),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _circle(scores.early, DraftColors.green, 'Early'),
          _circle(scores.mid, DraftColors.purple, 'Mid'),
          _circle(scores.late, DraftColors.red, 'Late'),
        ])
      ]),
    );
  }
}
