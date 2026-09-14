import 'package:flutter/material.dart';

/// 身體部位定義
enum BodyPart {
  head('頭部'),
  neck('脖子'),
  leftShoulder('左肩'),
  rightShoulder('右肩'),
  chest('胸部'),
  abdomen('腹部'),
  pelvis('骨盆/髖部'),
  leftArm('左手手臂'),
  rightArm('右手手臂'),
  leftLeg('左腿/膝蓋'),
  rightLeg('右腿/膝蓋'),
  leftFoot('左腳踝/腳掌'),
  rightFoot('右腳踝/腳掌');

  final String label;
  const BodyPart(this.label);
}

class BodyPainPicker extends StatefulWidget {
  final Function(Set<BodyPart> selectedParts)? onSelectionChanged;

  const BodyPainPicker({super.key, this.onSelectionChanged});

  @override
  State<BodyPainPicker> createState() => _BodyPainPickerState();
}

class _BodyPainPickerState extends State<BodyPainPicker> {
  final Set<BodyPart> _selectedParts = {};

  BodyPart? _detectPart(Offset pos) {
    // 1. 頭部 (中心 130, 45)
    if ((pos - const Offset(130, 45)).distance <= 22) {
      return BodyPart.head;
    }
    // 2. 脖子 (中心 130, 75)
    if (Rect.fromCenter(center: const Offset(130, 75), width: 26, height: 20)
        .contains(pos)) {
      return BodyPart.neck;
    }
    // 3. 肩膀 (鎖骨/肩線兩側)
    if (Rect.fromCenter(center: const Offset(110, 88), width: 30, height: 18)
        .contains(pos)) {
      return BodyPart.leftShoulder;
    }
    if (Rect.fromCenter(center: const Offset(150, 88), width: 30, height: 18)
        .contains(pos)) {
      return BodyPart.rightShoulder;
    }
    // 4. 胸、腹、髖
    if (Rect.fromCenter(center: const Offset(130, 105), width: 55, height: 30)
        .contains(pos)) {
      return BodyPart.chest;
    }
    if (Rect.fromCenter(center: const Offset(130, 140), width: 55, height: 30)
        .contains(pos)) {
      return BodyPart.abdomen;
    }
    if (Rect.fromCenter(center: const Offset(130, 175), width: 68, height: 32)
        .contains(pos)) {
      return BodyPart.pelvis;
    }
    // 5. 手臂
    if (Rect.fromLTWH(70, 98, 40, 120).contains(pos)) {
      return BodyPart.leftArm;
    }
    if (Rect.fromLTWH(150, 98, 40, 120).contains(pos)) {
      return BodyPart.rightArm;
    }
    // 6. 腿部
    if (Rect.fromLTWH(95, 195, 32, 155).contains(pos)) {
      return BodyPart.leftLeg;
    }
    if (Rect.fromLTWH(133, 195, 32, 155).contains(pos)) {
      return BodyPart.rightLeg;
    }
    // 7. 腳踝/腳掌
    if ((pos - const Offset(115, 365)).distance <= 20) {
      return BodyPart.leftFoot;
    }
    if ((pos - const Offset(145, 365)).distance <= 20) {
      return BodyPart.rightFoot;
    }
    return null;
  }

  void _handleTap(Offset localPos) {
    final hitPart = _detectPart(localPos);
    if (hitPart != null) {
      final selectedPart = hitPart;
      setState(() {
        if (_selectedParts.contains(selectedPart)) {
          _selectedParts.remove(selectedPart);
        } else {
          _selectedParts.add(selectedPart);
        }
      });
      widget.onSelectionChanged?.call(_selectedParts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition),
      child: CustomPaint(
        size: const Size(260, 390),
        painter: _StickFigurePainter(selectedParts: _selectedParts),
      ),
    );
  }
}

class _StickFigurePainter extends CustomPainter {
  final Set<BodyPart> selectedParts;

  _StickFigurePainter({required this.selectedParts});

  @override
  void paint(Canvas canvas, Size size) {
    final defaultStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    Paint getPartPaint(BodyPart part, {double activeWidth = 5.0}) {
      if (selectedParts.contains(part)) {
        return Paint()
          ..color = Colors.redAccent
          ..strokeWidth = activeWidth
          ..style = PaintingStyle.stroke;
      }
      return defaultStroke;
    }

    // 1. 頭部
    final headCenter = const Offset(130, 45);
    if (selectedParts.contains(BodyPart.head)) {
      canvas.drawCircle(
          headCenter,
          20,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.fill);
    }
    canvas.drawCircle(headCenter, 20, defaultStroke);

    // 2. 脖子 (獨立判定與變色)
    final neckPaint = getPartPaint(BodyPart.neck, activeWidth: 6.0);
    canvas.drawLine(const Offset(130, 65), const Offset(130, 85), neckPaint);

    // 3. 肩膀水平線 (左肩與右肩分開染色)
    final lShoulderPaint =
        getPartPaint(BodyPart.leftShoulder, activeWidth: 5.5);
    final rShoulderPaint =
        getPartPaint(BodyPart.rightShoulder, activeWidth: 5.5);
    canvas.drawLine(
        const Offset(130, 85), const Offset(105, 92), lShoulderPaint);
    canvas.drawLine(
        const Offset(130, 85), const Offset(155, 92), rShoulderPaint);

    // 4. 軀幹三個橢圓 (胸、腹、髖)
    _drawOval(
        canvas, const Offset(130, 105), 24, 15, BodyPart.chest, defaultStroke);
    _drawOval(canvas, const Offset(130, 140), 24, 15, BodyPart.abdomen,
        defaultStroke);
    _drawOval(
        canvas, const Offset(130, 175), 30, 16, BodyPart.pelvis, defaultStroke);

    // 5. 手臂
    final armPaintL = getPartPaint(BodyPart.leftArm);
    final armPaintR = getPartPaint(BodyPart.rightArm);
    canvas.drawLine(const Offset(105, 92), const Offset(90, 145), armPaintL);
    canvas.drawLine(const Offset(90, 145), const Offset(85, 195), armPaintL);

    canvas.drawLine(const Offset(155, 92), const Offset(170, 145), armPaintR);
    canvas.drawLine(const Offset(170, 145), const Offset(175, 195), armPaintR);

    // 6. 雙腿
    final legPaintL = getPartPaint(BodyPart.leftLeg);
    final legPaintR = getPartPaint(BodyPart.rightLeg);
    canvas.drawLine(const Offset(115, 190), const Offset(115, 350), legPaintL);
    canvas.drawLine(const Offset(145, 190), const Offset(145, 350), legPaintR);

    // 7. 腳掌
    _drawOval(canvas, const Offset(115, 365), 7, 12, BodyPart.leftFoot,
        defaultStroke);
    _drawOval(canvas, const Offset(145, 365), 7, 12, BodyPart.rightFoot,
        defaultStroke);
  }

  void _drawOval(Canvas canvas, Offset center, double rx, double ry,
      BodyPart part, Paint strokePaint) {
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    if (selectedParts.contains(part)) {
      canvas.drawOval(
          rect,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.fill);
    }
    canvas.drawOval(rect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _StickFigurePainter oldDelegate) {
    return oldDelegate.selectedParts != selectedParts;
  }
}
