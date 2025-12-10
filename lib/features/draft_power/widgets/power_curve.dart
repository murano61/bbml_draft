import 'package:flutter/material.dart';
import '../colors.dart';

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    Path ally = Path()..moveTo(5/310*w, 110/192*h)
      ..cubicTo(80/310*w, 90/192*h, 230/310*w, 50/192*h, 305/310*w, 20/192*h)
      ..lineTo(305/310*w, h)
      ..lineTo(5/310*w, h)
      ..close();
    Path enemy = Path()..moveTo(5/310*w, 80/192*h)
      ..cubicTo(80/310*w, 65/192*h, 230/310*w, 40/192*h, 305/310*w, 10/192*h)
      ..lineTo(305/310*w, h)
      ..lineTo(5/310*w, h)
      ..close();
    final allyFill = Paint()
      ..shader = const LinearGradient(colors: [Color(0x2610C299), Color(0x0010C299)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0,0,w,h));
    final enemyFill = Paint()
      ..shader = const LinearGradient(colors: [Color(0x26FF5353), Color(0x00FF5353)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0,0,w,h));
    canvas.drawPath(ally, allyFill);
    canvas.drawPath(enemy, enemyFill);
    final allyStroke = Paint()..color = DraftColors.green..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final enemyStroke = Paint()..color = DraftColors.red..style = PaintingStyle.stroke..strokeWidth = 2.5;
    Path allyLine = Path()..moveTo(5/310*w, 110/192*h)
      ..cubicTo(80/310*w, 90/192*h, 230/310*w, 50/192*h, 305/310*w, 20/192*h);
    Path enemyLine = Path()..moveTo(5/310*w, 80/192*h)
      ..cubicTo(80/310*w, 65/192*h, 230/310*w, 40/192*h, 305/310*w, 10/192*h);
    canvas.drawPath(allyLine, allyStroke);
    canvas.drawPath(enemyLine, enemyStroke);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PowerCurve extends StatelessWidget {
  const PowerCurve({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: DraftColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Oyun Aşamalarına Göre Güç Eğrisi', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: DraftColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 192,
          child: Stack(children: [
            CustomPaint(size: const Size(double.infinity, double.infinity), painter: _CurvePainter()),
            const Positioned.fill(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Erken', style: TextStyle(color: DraftColors.textSecondary)),
              Text('Orta', style: TextStyle(color: DraftColors.textSecondary)),
              Text('Geç', style: TextStyle(color: DraftColors.textSecondary)),
            ]))))
          ]),
        ),
      ]),
    );
  }
}
