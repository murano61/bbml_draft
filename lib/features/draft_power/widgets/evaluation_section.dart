import 'package:flutter/material.dart';
import '../colors.dart';
import '../models.dart';

class EvaluationSection extends StatelessWidget {
  final EvaluationPlan plan;
  const EvaluationSection({super.key, required this.plan});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Draft Değerlendirmesi', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Kazanan: ${plan.winner}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: plan.winner.toLowerCase().contains('rakip') ? DraftColors.red : DraftColors.green, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('Oyun Planı', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: DraftColors.textSecondary)),
        const SizedBox(height: 8),
        Text('Early: ${plan.early}', style: const TextStyle(color: DraftColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Mid: ${plan.mid}', style: const TextStyle(color: DraftColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Late: ${plan.late}', style: const TextStyle(color: DraftColors.textPrimary)),
      ]),
    );
  }
}
