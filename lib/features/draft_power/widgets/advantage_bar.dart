import 'package:flutter/material.dart';
import '../colors.dart';

class AdvantageBar extends StatelessWidget {
  final double leftPercent;
  final EdgeInsetsGeometry padding;
  const AdvantageBar({super.key, required this.leftPercent, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) {
    final lp = leftPercent.clamp(0, 100);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 4,
          decoration: BoxDecoration(color: DraftColors.red, borderRadius: BorderRadius.circular(2)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: lp / 100, child: Container(color: DraftColors.green)),
          ),
        ),
      ]),
    );
  }
}
