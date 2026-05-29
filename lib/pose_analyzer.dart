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

    // ======== 核心演算法：角度相似度 (Angle Similarity) ========
    // 滿分 100 分，由三個部位的角度相似度加總：軀幹(20分) + 手臂(40分) + 膝蓋(40分)
    double currentAccuracy = 0.0;
    
    // 1. 軀幹前傾角度 (Torso Angle) - 權重 20分
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
      double leftTorsoAngle = _calculateAngleWithVertical(leftShoulder, leftHip);
      double rightTorsoAngle = _calculateAngleWithVertical(rightShoulder, rightHip);
      double avgTorsoAngle = (leftTorsoAngle + rightTorsoAngle) / 2;

      // 完美慢跑軀幹角度：5° ~ 15°
      double torsoScore = 20.0;
      if (avgTorsoAngle < 5) {
        torsoScore -= (5 - avgTorsoAngle) * 2; // 太直
      } else if (avgTorsoAngle > 15) {
        torsoScore -= (avgTorsoAngle - 15) * 1.5; // 太彎
      }
      if (torsoScore < 0) torsoScore = 0;
      currentAccuracy += torsoScore;

      if (avgTorsoAngle > 25) {
        _leanForwardFrames++;
        if (_leanForwardFrames > 15) _currentFeedback.add('身體太前傾了，請挺直腰桿！');
      } else {
        _leanForwardFrames = 0;
      }
    }

    // 2. 手臂擺動與彎曲角度 (Arm Bend Angle) - 權重 40分 (左右手各 20分)
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    double calculateArmScore(PoseLandmark? s, PoseLandmark? e, PoseLandmark? w) {
      if (s == null || e == null || w == null) return 0; // 沒抓到手給0分
      double angle = _calculateAngle3P(s, e, w);
      // 完美手肘角度：75° ~ 105° (約 90°)
      double score = 20.0;
      if (angle < 75) {
        score -= (75 - angle) * 0.5;
      } else if (angle > 105) {
        score -= (angle - 105) * 0.5; // 伸直(180)會大扣分 (180-105)*0.5 = 37.5 -> 變0分
      }
      return math.max(0.0, score);
    }
    
    currentAccuracy += calculateArmScore(leftShoulder, leftElbow, leftWrist);
    currentAccuracy += calculateArmScore(rightShoulder, rightElbow, rightWrist);

    // 3. 膝蓋微彎與彈性 (Knee Angle) - 權重 40分 (左右腳各 20分)
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    double calculateKneeScore(PoseLandmark? h, PoseLandmark? k, PoseLandmark? a) {
      if (h == null || k == null || a == null) return 0;
      double angle = _calculateAngle3P(h, k, a);
      
      // 👗 長褲誤差補償機制 (Clothing Compensation)
      double maxIdealAngle = 165.0; // 預設最大完美角度 (超過代表站太直)
      if (k.likelihood < 0.7) {
        maxIdealAngle = 175.0; // 若信心度低(可能穿長褲)，放寬容錯至175度
      }

      // 完美膝蓋緩衝角度：130° ~ maxIdealAngle
      double score = 20.0;
      if (angle < 130) {
        score -= (130 - angle) * 0.5; // 蹲太低
      } else if (angle > maxIdealAngle) {
        score -= (angle - maxIdealAngle) * 1.5; // 站直(180)大扣分 (180-165)*1.5 = 22.5 -> 變0分
      }
      return math.max(0.0, score);
    }

    currentAccuracy += calculateKneeScore(leftHip, leftKnee, leftAnkle);
    currentAccuracy += calculateKneeScore(rightHip, rightKnee, rightAnkle);

    // ======== 動態步數計算與怠速懲罰 ========
    if (leftKnee != null && rightKnee != null) {
      double yDiff = leftKnee.y - rightKnee.y;
      bool stepTaken = false;
      
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
        DateTime referenceTime = _lastStepTime ?? _firstFrameTime!;
        if (DateTime.now().difference(referenceTime).inMilliseconds > 1500) {
          _standingStillFrames++;
          currentAccuracy -= 50.0; // 除了角度拿不到滿分外，定格不動再直接倒扣 50 分！
          if (_standingStillFrames > 10) {
             _currentFeedback.add('請保持動作，不要停下來喔！');
          }
        }
      }
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

  // Calculate angle between 3 points (a -> b -> c)
  double _calculateAngle3P(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    double radians = math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double angle = radians * 180.0 / math.pi;
    angle = angle.abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
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
