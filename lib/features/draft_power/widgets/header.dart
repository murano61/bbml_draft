import 'package:flutter/material.dart';
import '../colors.dart';

class DraftHeader extends StatelessWidget {
  const DraftHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: Text('Draft Güç Analizi', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
