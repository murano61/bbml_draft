import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'models.dart';

class HeroSlot extends StatelessWidget {
  final VoidCallback onTap;
  const HeroSlot({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accentPink, width: 1.4),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.add, color: AppColors.textSecondary),
      ),
    );
  }
}

class HeroAvatar extends StatelessWidget {
  final HeroPick pick;
  const HeroAvatar({super.key, required this.pick});
  @override
  Widget build(BuildContext context) {
    final glow = pick.isSTier ? AppColors.primaryNeon : Colors.transparent;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: glow, blurRadius: pick.isSTier ? 12 : 0)],
            border: Border.all(color: AppColors.accentPink, width: 1.2),
          ),
          child: ClipOval(child: Container(color: AppColors.card, child: Center(child: Text(pick.heroName.characters.first.toUpperCase())))),
        ),
        const SizedBox(height: 6),
        Text(pick.role.laneLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class NeonRingLoader extends StatefulWidget {
  const NeonRingLoader({super.key});
  @override
  State<NeonRingLoader> createState() => _NeonRingLoaderState();
}

class _NeonRingLoaderState extends State<NeonRingLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return CustomPaint(
            painter: _RingPainter(progress: _c.value),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final r1 = size.width*0.35;
    final r2 = size.width*0.45;
    final p1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = AppColors.accentPurple;
    final p2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.warning;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r1), progress*6.283, 4.2, false, p1);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r2), -progress*6.283, 3.6, false, p2);
  }
  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class ScoreCard extends StatelessWidget {
  final int score;
  final String tierLabel;
  final String subtitle;
  const ScoreCard({super.key, required this.score, required this.tierLabel, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$score', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(tierLabel, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(subtitle),
      ]),
    );
  }
}

class MetricTabBar extends StatelessWidget {
  final MetricTab selected;
  final ValueChanged<MetricTab> onChanged;
  const MetricTabBar({super.key, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    Widget tab(MetricTab t, String label) {
      final active = selected == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? AppColors.primaryNeon : AppColors.accentPink, width: 1.4),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(color: active ? AppColors.textPrimary : AppColors.textSecondary)),
          ),
        ),
      );
    }
    return Row(children: [
      tab(MetricTab.general, 'Genel'),
      const SizedBox(width: 8),
      tab(MetricTab.strategy, 'Strateji'),
      const SizedBox(width: 8),
      tab(MetricTab.metaDifficulty, 'Meta & Zorluk'),
    ]);
  }
}

class MetricBar extends StatelessWidget {
  final Metric metric;
  const MetricBar({super.key, required this.metric});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(metric.title),
          Text('${metric.score}/100', style: const TextStyle(color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth;
          final p = metric.score/100;
          return Stack(children: [
            Container(height: 8, width: w, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8))),
            Container(height: 8, width: w*p, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.accentPurple, AppColors.primaryNeon]), borderRadius: BorderRadius.circular(8))),
          ]);
        }),
        const SizedBox(height: 6),
        Text(metric.description, style: const TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

class AiSuggestionsCard extends StatelessWidget {
  final List<AiSuggestion> suggestions;
  final VoidCallback onCta;
  const AiSuggestionsCard({super.key, required this.suggestions, required this.onCta});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AI Önerileri', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...suggestions.map((s) => Row(children: [
          const Icon(Icons.bolt, color: AppColors.primaryNeon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(s.text)),
        ])),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onCta, child: const Text('BBML Build ile buildleri gör'))),
      ]),
    );
  }
}
