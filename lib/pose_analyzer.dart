import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseAnalysisResult {
  final double accuracy;
  final List<String> feedback;
  final int stepCount;

  PoseAnalysisResult({
    required this.accuracy,
    required this.feedback,
    required this.stepCount,
  });
}

class PoseAnalyzer {
  int _stepCount = 0;
  bool _isKneeHigh = false;
  
  // Track continuous bad posture
  int _leanForwardFrames = 0;
  int _lowKneeFrames = 0;
  
  // To avoid redundant feedback
  final Set<String> _currentFeedback = {};

  PoseAnalysisResult analyze(List<Pose> poses) {
    if (poses.isEmpty) {
      return PoseAnalysisResult(
        accuracy: 0.0,
        feedback: ['請站在鏡頭前'],
        stepCount: _stepCount,
      );
    }

    final pose = poses.first;
    _currentFeedback.clear();
    double currentAccuracy = 100.0;

    // 1. Core Posture Analysis (Back should be straight)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
      // Calculate torso angle relative to vertical
      double leftTorsoAngle = _calculateAngleWithVertical(leftShoulder, leftHip);
      double rightTorsoAngle = _calculateAngleWithVertical(rightShoulder, rightHip);
      double avgTorsoAngle = (leftTorsoAngle + rightTorsoAngle) / 2;

      // Super slow running implies an upright posture. Angle > 15 degrees is leaning.
      if (avgTorsoAngle > 15) {
        _leanForwardFrames++;
        currentAccuracy -= (avgTorsoAngle - 15) * 2; // Penalize based on severity
        if (_leanForwardFrames > 10) {
          _currentFeedback.add('身體太前傾了，請挺直腰桿！');
        }
      } else {
        _leanForwardFrames = 0;
      }
    }

    // 2. Leg Action Analysis (Knees should lift, but loose clothing compensation applied)
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftKnee != null && rightKnee != null) {
      // Clothing Compensation Logic:
      // If the model's confidence in the knee/ankle is very low (e.g., baggy pants obscuring joint),
      // we reduce the penalty and rely more on general hip bounce.
      double minLikelihood = math.min(leftKnee.likelihood, rightKnee.likelihood);
      double toleranceMultiplier = minLikelihood < 0.6 ? 0.5 : 1.0; // 50% penalty reduction if loose clothing suspected

      // Calculate relative Y distance between hip and knee (negative is up in screen space)
      double leftKneeHeight = (leftHip?.y ?? 0) - leftKnee.y;
      double rightKneeHeight = (rightHip?.y ?? 0) - rightKnee.y;

      // Simple relative threshold for lifting knee.
      double liftThreshold = 50.0;

      if (leftKneeHeight < liftThreshold && rightKneeHeight < liftThreshold) {
         _lowKneeFrames++;
         currentAccuracy -= (10 * toleranceMultiplier); // Apply penalty with tolerance
         if (_lowKneeFrames > 15) {
             _currentFeedback.add('膝蓋可以稍微抬高一點喔！');
         }
      } else {
         _lowKneeFrames = 0;
      }

      // Step Counting Logic (Simple alternating Y peak detection)
      // Check if one knee is significantly higher than the other, creating an alternating cycle
      if (leftKneeHeight > rightKneeHeight + 20) {
        if (!_isKneeHigh) {
          _stepCount++;
          _isKneeHigh = true;
        }
      } else if (rightKneeHeight > leftKneeHeight + 20) {
        if (_isKneeHigh) {
          _stepCount++;
          _isKneeHigh = false;
        }
      }
    }

    if (currentAccuracy < 0) currentAccuracy = 0;

    return PoseAnalysisResult(
      accuracy: currentAccuracy,
      feedback: _currentFeedback.toList(),
      stepCount: _stepCount,
    );
  }

  // Calculate angle between two points and the vertical axis (0 is perfectly vertical)
  double _calculateAngleWithVertical(PoseLandmark top, PoseLandmark bottom) {
    double dx = bottom.x - top.x;
    double dy = bottom.y - top.y;
    double angle = math.atan2(dx.abs(), dy.abs()) * 180 / math.pi;
    return angle;
  }
}
