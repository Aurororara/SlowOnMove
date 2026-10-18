import 'package:flutter/material.dart';

import 'group_pose_frame.dart';

class GroupPosePainter extends CustomPainter {
  final GroupPoseFrame frame;
  GroupPosePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final fitted =
        applyBoxFit(BoxFit.contain, Size(frame.aspectRatio, 1), size);
    final rect =
        Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final joints = {for (final p in frame.points) p.id: p};
    Offset position(GroupPosePoint p) =>
        Offset(rect.left + p.x * rect.width, rect.top + p.y * rect.height);
    final line = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.5;
    final dot = Paint()..color = Colors.amberAccent;
    canvas.save();
    canvas.clipRect(rect);
    for (final edge in groupPoseConnections) {
      final a = joints[edge.$1], b = joints[edge.$2];
      if (a != null &&
          b != null &&
          a.confidence >= 0.5 &&
          b.confidence >= 0.5) {
        canvas.drawLine(position(a), position(b), line);
      }
    }
    for (final point in joints.values) {
      if (point.confidence >= 0.5) canvas.drawCircle(position(point), 3, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GroupPosePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
