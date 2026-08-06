import 'package:flutter/material.dart';

enum FilterType {
  flat,
  lowShelf,
  peaking,
  highShelf,
  lowPassLinkwitz,
  highPassLinkwitz,
  lowPassButterworth,
  highPassButterworth,
  lowPassBessel,
  highPassBessel,
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
      case 0: // PEAKING / PK (Rhombus / Peak shape in middle)
        path.moveTo(0, midY);
        path.lineTo(w * 0.25, midY);
        path.lineTo(w * 0.5, h * 0.15);
        path.lineTo(w * 0.75, midY);
        path.lineTo(w, midY);
        path.moveTo(w * 0.25, midY);
        path.lineTo(w * 0.5, h * 0.85);
        path.lineTo(w * 0.75, midY);
        break;

      case 1: // LOW_SHELF / LS (Branching up/down on left, joining to flat right midY)
        path.moveTo(0, h * 0.15);
        path.lineTo(w * 0.35, h * 0.15);
        path.lineTo(w * 0.65, midY);
        path.lineTo(w, midY);
        path.moveTo(0, h * 0.85);
        path.lineTo(w * 0.35, h * 0.85);
        path.lineTo(w * 0.65, midY);
        break;

      case 2: // HIGH_SHELF / HS (Flat on left midY, branching up/down on right)
        path.moveTo(0, midY);
        path.lineTo(w * 0.35, midY);
        path.lineTo(w * 0.65, h * 0.15);
        path.lineTo(w, h * 0.15);
        path.moveTo(w * 0.35, midY);
        path.lineTo(w * 0.65, h * 0.85);
        path.lineTo(w, h * 0.85);
        break;

      case 3: // LOW_PASS / LP_2nd / LP (Flat top left, steep slope down right)
        path.moveTo(0, h * 0.2);
        path.lineTo(w * 0.5, h * 0.2);
        path.lineTo(w * 0.95, h * 0.95);
        break;

      case 4: // HIGH_PASS / HP_2nd / HP (Slope up from bottom left, flat top right)
        path.moveTo(0, h * 0.95);
        path.lineTo(w * 0.5, h * 0.2);
        path.lineTo(w, h * 0.2);
        break;

      case 5: // BAND_PASS / BP (Trapezoid / hill shape)
        path.moveTo(0, h * 0.9);
        path.lineTo(w * 0.3, h * 0.2);
        path.lineTo(w * 0.7, h * 0.2);
        path.lineTo(w, h * 0.9);
        break;

      case 6: // NOTCH / NH / NOTCH (V dip in middle)
        path.moveTo(0, h * 0.2);
        path.lineTo(w * 0.35, h * 0.2);
        path.lineTo(w * 0.5, h * 0.85);
        path.lineTo(w * 0.65, h * 0.2);
        path.lineTo(w, h * 0.2);
        break;

      case 7: // LOW_PASS_ORDER1 / LP_1st / LO (Gentle curve down right)
        path.moveTo(0, h * 0.2);
        path.lineTo(w * 0.4, h * 0.2);
        path.quadraticBezierTo(w * 0.75, h * 0.3, w, h * 0.85);
        break;

      case 8: // HIGH_PASS_ORDER1 / HP_1st / HO (Gentle curve up left to flat right)
        path.moveTo(0, h * 0.85);
        path.quadraticBezierTo(w * 0.25, h * 0.7, w * 0.6, h * 0.2);
        path.lineTo(w, h * 0.2);
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
