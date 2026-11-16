import 'package:material_ui/material_ui.dart';

enum BearMood { happy, sleepy, careful }

class BearMascot extends StatelessWidget {
  const BearMascot({super.key, this.size = 76, this.mood = BearMood.happy});

  final double size;
  final BearMood mood;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _BearPainter(mood)),
  );
}

class _BearPainter extends CustomPainter {
  const _BearPainter(this.mood);
  final BearMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final brown = Paint()..color = const Color(0xFF8C5539);
    final dark = Paint()..color = const Color(0xFF402B25);
    final muzzle = Paint()..color = const Color(0xFFF2D8B8);
    final blush = Paint()..color = const Color(0xFFE89A83);
    canvas.drawCircle(const Offset(25, 25), 15, brown);
    canvas.drawCircle(const Offset(75, 25), 15, brown);
    canvas.drawCircle(const Offset(25, 26), 7, muzzle);
    canvas.drawCircle(const Offset(75, 26), 7, muzzle);
    canvas.drawOval(const Rect.fromLTWH(17, 21, 66, 72), brown);
    canvas.drawCircle(const Offset(50, 45), 34, brown);
    canvas.drawOval(const Rect.fromLTWH(32, 48, 36, 26), muzzle);
    canvas.drawCircle(const Offset(39, 44), 3.3, dark);
    canvas.drawCircle(const Offset(61, 44), 3.3, dark);
    canvas.drawCircle(const Offset(31, 57), 5, blush);
    canvas.drawCircle(const Offset(69, 57), 5, blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 54), width: 9, height: 6), dark);
    final mouth = Paint()
      ..color = dark.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (mood == BearMood.sleepy) {
      path.moveTo(44, 64);
      path.lineTo(56, 64);
      canvas.drawOval(Rect.fromCenter(center: const Offset(39, 43), width: 8, height: 2), dark);
      canvas.drawOval(Rect.fromCenter(center: const Offset(61, 43), width: 8, height: 2), dark);
    } else if (mood == BearMood.careful) {
      path.moveTo(44, 65);
      path.quadraticBezierTo(50, 59, 56, 65);
      canvas.drawLine(const Offset(35, 38), const Offset(43, 40), mouth);
      canvas.drawLine(const Offset(57, 40), const Offset(65, 38), mouth);
    } else {
      path.moveTo(42, 61);
      path.quadraticBezierTo(50, 70, 58, 61);
    }
    canvas.drawPath(path, mouth);
    canvas.drawArc(const Rect.fromLTWH(24, 8, 13, 13), 3.4, 1.2, false, Paint()..color = Colors.white.withValues(alpha: .55)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _BearPainter oldDelegate) => oldDelegate.mood != mood;
}
