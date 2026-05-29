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
  final int _lowKneeFrames = 0;
  
  // To avoid redundant feedback
  final Set<String> _currentFeedback = {};

  DateTime? _lastAnalyzeTime;
  PoseAnalysisResult? _lastResult;
  
  DateTime? _firstFrameTime;
  DateTime? _lastStepTime;
  int _standingStillFrames = 0;

  PoseAnalysisResult analyze(List<Pose> poses) {
    if (poses.isEmpty) {
      return PoseAnalysisResult(
        accuracy: 0.0,
        feedback: ['請站在鏡頭前'],
        stepCount: _stepCount,
      );
    }

    final currentTime = DateTime.now();
    if (_lastAnalyzeTime != null && _lastResult != null && 
        currentTime.difference(_lastAnalyzeTime!).inMilliseconds < 50) {
      return _lastResult!;
    }
    _lastAnalyzeTime = currentTime;
    _firstFrameTime ??= currentTime;

    final pose = poses.first;
    _currentFeedback.clear();
    double currentAccuracy = 100.0;

    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    bool noLegsDetected = false;
    if (leftKnee == null || rightKnee == null) {
      noLegsDetected = true;
    } else {
      double minLikelihood = math.min(leftKnee.likelihood, rightKnee.likelihood);
      if (minLikelihood < 0.2) {
        noLegsDetected = true;
      }
    }

    if (noLegsDetected) {
      _lastResult = PoseAnalysisResult(
        accuracy: 0.0,
        feedback: ['沒有拍攝到腿部，請調整鏡頭角度！'],
        stepCount: _stepCount,
      );
      return _lastResult!;
    }

    // 1. Core Posture Analysis (Back should be straight)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
      double leftTorsoAngle = _calculateAngleWithVertical(leftShoulder, leftHip);
      double rightTorsoAngle = _calculateAngleWithVertical(rightShoulder, rightHip);
      double avgTorsoAngle = (leftTorsoAngle + rightTorsoAngle) / 2;

      // 超慢跑允許微微前傾，大於 25 度才開始扣分
      if (avgTorsoAngle > 25) {
        _leanForwardFrames++;
        currentAccuracy -= (avgTorsoAngle - 25); // 減輕扣分幅度
        if (_leanForwardFrames > 15) {
          _currentFeedback.add('身體太前傾了，請挺直腰桿！');
        }
      } else {
        _leanForwardFrames = 0;
      }
    }

    // 2. Leg Action Analysis (Step counting using knee Y differences)
    if (leftKnee != null && rightKnee != null) {
      // 在 ML Kit 中，Y 越小代表在畫面上越上方
      double yDiff = leftKnee.y - rightKnee.y;
      bool stepTaken = false;
      
      // 將門檻從 12 提高到 30，避免相機雜訊（微小晃動）被誤判為走路
      if (yDiff < -30) {
        if (!_isKneeHigh) {
          _stepCount++;
          _isKneeHigh = true;
          stepTaken = true;
        }
      } else if (yDiff > 30) {
        if (_isKneeHigh) {
          _stepCount++;
          _isKneeHigh = false;
          stepTaken = true;
        }
      }
      
      if (stepTaken) {
        _lastStepTime = DateTime.now();
        _standingStillFrames = 0;
      } else {
        // 把怠速時間縮短到 1.5 秒，並且加重扣分，讓測試時非常有感
        DateTime referenceTime = _lastStepTime ?? _firstFrameTime!;
        if (DateTime.now().difference(referenceTime).inMilliseconds > 1500) {
          _standingStillFrames++;
          currentAccuracy -= 80.0; // 定格不動直接扣 80 分（畫面上會直接掉到 20%）
          if (_standingStillFrames > 10) {
             _currentFeedback.add('請保持動作，不要停下來喔！');
          }
        }
      }
      
      // 移除原本不合理的膝蓋高度扣分邏輯，因為：
      // 1. 原本的 leftHip.y - leftKnee.y 是負數，導致永遠小於 threshold，永遠被扣分
      // 2. 超慢跑本來就「不需要」高抬膝，步伐小是正常的
    }

    if (currentAccuracy < 0) currentAccuracy = 0;
    if (currentAccuracy > 100) currentAccuracy = 100;

    _lastResult = PoseAnalysisResult(
      accuracy: currentAccuracy,
      feedback: _currentFeedback.toList(),
      stepCount: _stepCount,
    );
    return _lastResult!;
  }

  // Calculate angle between two points and the vertical axis (0 is perfectly vertical)
  double _calculateAngleWithVertical(PoseLandmark top, PoseLandmark bottom) {
    double dx = bottom.x - top.x;
    double dy = bottom.y - top.y;
    double angle = math.atan2(dx.abs(), dy.abs()) * 180 / math.pi;
    return angle;
  }

  /// [Placeholder] For future Teachable Machine TFLite model inference
  /// This will be used to refine the accuracy score based on custom trained models.
  Future<void> loadModel() async {
    // TODO: Implement TFLite model loading using flutter_tflite
    print("TFLite model loading placeholder called.");
  }

  Future<double> runTFLiteInference() async {
    // TODO: Implement inference logic
    return 1.0; // Placeholder returning full accuracy
  }
}
