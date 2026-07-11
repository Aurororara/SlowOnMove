import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'coordinates_translator.dart';

// Helper properties mimicking Python state
int stepCount = 0;
bool isFootOnGround = false;
DateTime startTime = DateTime.now();

class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.imageSize, this.rotation, this.cameraLensDirection);

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blue;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        // Draw all points
        canvas.drawCircle(
            Offset(
              translateX(landmark.x, size, imageSize, rotation, cameraLensDirection),
              translateY(landmark.y, size, imageSize, rotation, cameraLensDirection),
            ),
            4,
            pointPaint);
      });

      // Connections lines Drawing like MediaPipe
      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        if (joint1.likelihood < 0.5 || joint2.likelihood < 0.5) return;
        canvas.drawLine(
            Offset(translateX(joint1.x, size, imageSize, rotation, cameraLensDirection),
                translateY(joint1.y, size, imageSize, rotation, cameraLensDirection)),
            Offset(translateX(joint2.x, size, imageSize, rotation, cameraLensDirection),
                translateY(joint2.y, size, imageSize, rotation, cameraLensDirection)),
            paintType);
      }
      
      // Paint Left Body Lines
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, leftPaint);
      paintLine(PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex, leftPaint);
      paintLine(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex, leftPaint);
      
      // Right Body Lines (optional but good for tracking)
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, rightPaint);
      paintLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, rightPaint);
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
      paintLine(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, rightPaint);
      paintLine(PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex, rightPaint);
      paintLine(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex, rightPaint);


      // --- Logic Implementation ---
      PoseLandmark? leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      PoseLandmark? leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
      PoseLandmark? leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
      PoseLandmark? leftHeel = pose.landmarks[PoseLandmarkType.leftHeel];
      PoseLandmark? leftToe = pose.landmarks[PoseLandmarkType.leftFootIndex];

      if (leftHip == null || leftKnee == null || leftAnkle == null || leftHeel == null || leftToe == null) continue;


      // check relative to imageSize.height
      double currentFootYRelative = leftAnkle.y / imageSize.height;
      if (currentFootYRelative > 0.85 && !isFootOnGround) {
        isFootOnGround = true;
        stepCount++;
      } else if (currentFootYRelative < 0.82) {
        isFootOnGround = false;
      }

      // 依據使用者要求，黑色框下方三段提示文字目前不繪製於 Canvas
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses || oldDelegate.imageSize != imageSize;
  }
}
