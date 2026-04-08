import 'package:flutter/material.dart';

enum FilterType {
  peaking,
  lowShelf,
  highShelf,
  lowPass,
  highPass,
  bandPass,
  notch,
}

class FilterIcon extends StatelessWidget {
  final int typeIndex;
  final Color color;
  final double width;
  final double height;

  const FilterIcon({
    super.key,
    required this.typeIndex,
    this.color = Colors.red,
    this.width = 30,
    this.height = 15,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FilterIconPainter(typeIndex, color),
      ),
    );
  }
}

class _FilterIconPainter extends CustomPainter {
  final int typeIndex;
  final Color color;

  _FilterIconPainter(this.typeIndex, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;
    final w = size.width;
    final h = size.height;

    switch (typeIndex) {
      case 0: // PEAKING / Peak
        path.moveTo(0, midY);
        path.lineTo(w * 0.3, midY);
        path.lineTo(w * 0.5, h * 0.2);
        path.lineTo(w * 0.7, midY);
        path.lineTo(w * 0.5, h * 0.8);
        path.lineTo(w * 0.3, midY);
        path.moveTo(w * 0.7, midY);
        path.lineTo(w, midY);
        path.moveTo(w * 0.3, midY);
        path.lineTo(w * 0.7, midY);
        break;

      case 1: // LOW_SHELF / LSF
        path.moveTo(0, h * 0.7);
        path.lineTo(w * 0.4, h * 0.7);
        path.lineTo(w * 0.6, h * 0.3);
        path.lineTo(w, h * 0.3);
        break;

      case 2: // HIGH_SHELF / HSF
        path.moveTo(0, h * 0.3);
        path.lineTo(w * 0.4, h * 0.3);
        path.lineTo(w * 0.6, h * 0.7);
        path.lineTo(w, h * 0.7);
        break;

      case 3: // LOW_PASS / LPF
        path.moveTo(0, h * 0.3);
        path.lineTo(w * 0.6, h * 0.3);
        path.quadraticBezierTo(w * 0.8, h * 0.3, w, h);
        break;

      case 4: // HIGH_PASS / HPF
        path.moveTo(0, h);
        path.quadraticBezierTo(w * 0.2, h * 0.3, w * 0.4, h * 0.3);
        path.lineTo(w, h * 0.3);
        break;

      case 5: // BAND_PASS / BPF
        path.moveTo(0, h);
        path.lineTo(w * 0.35, h * 0.3);
        path.lineTo(w * 0.65, h * 0.3);
        path.lineTo(w, h);
        break;

      case 6: // NOTCH / Notch
        path.moveTo(0, h * 0.3);
        path.lineTo(w * 0.4, h * 0.3);
        path.lineTo(w * 0.5, h * 0.8);
        path.lineTo(w * 0.6, h * 0.3);
        path.lineTo(w, h * 0.3);
        break;

      case 7: // LOW_PASS_ORDER1
        path.moveTo(0, h * 0.3);
        path.lineTo(w * 0.5, h * 0.3);
        path.lineTo(w, h * 0.8);
        break;

      case 8: // HIGH_PASS_ORDER1
        path.moveTo(0, h * 0.8);
        path.lineTo(w * 0.5, h * 0.3);
        path.lineTo(w, h * 0.3);
        break;

      default:
        path.moveTo(0, midY);
        path.lineTo(w, midY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FilterIconPainter oldDelegate) => 
    oldDelegate.typeIndex != typeIndex || oldDelegate.color != color;
}
