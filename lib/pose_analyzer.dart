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

  bool _isSquattingDown = false; // 深蹲狀態機

  PoseAnalysisResult analyze(List<Pose> poses, {String exerciseType = '超慢跑'}) {
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
    double currentAccuracy = 0.0;
    
    // 擷取全身關鍵點
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // 🕵️ 自動視角辨識 (Auto-Perspective Detection)
    bool isSideFacing = false;
    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null) {
      double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
      double torsoHeight = ((leftShoulder.y + rightShoulder.y) / 2 - (leftHip.y + rightHip.y) / 2).abs();
      if (torsoHeight > 0 && (shoulderWidth / torsoHeight) < 0.35) {
        isSideFacing = true; // 側身時，肩膀在 2D 畫面上看起來會很窄
      }
    }

    // 計算關節角度輔助函數
    double getAngle(PoseLandmark? a, PoseLandmark? b, PoseLandmark? c) {
      if (a == null || b == null || c == null) return 180.0;
      return _calculateAngle3P(a, b, c);
    }

    double leftArmAngle = getAngle(leftShoulder, leftElbow, leftWrist);
    double rightArmAngle = getAngle(rightShoulder, rightElbow, rightWrist);
    double leftKneeAngle = getAngle(leftHip, leftKnee, leftAnkle);
    double rightKneeAngle = getAngle(rightHip, rightKnee, rightAnkle);

    bool stepTaken = false;

    // ==========================================
    // 🏋️‍♂️ 運動模式分流 (Exercise Mode Branching)
    // ==========================================
    if (exerciseType == '深蹲') {
      
      // 1. 深蹲軀幹前傾 (20分)
      if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
        double leftTorsoAngle = _calculateAngleWithVertical(leftShoulder, leftHip);
        double rightTorsoAngle = _calculateAngleWithVertical(rightShoulder, rightHip);
        double activeTorsoAngle = isSideFacing ?
            ((leftShoulder.likelihood + leftHip.likelihood) > (rightShoulder.likelihood + rightHip.likelihood) ? leftTorsoAngle : rightTorsoAngle)
            : (leftTorsoAngle + rightTorsoAngle) / 2;
        
        double torsoScore = 20.0;
        // 允許 0~45 度前傾
        if (activeTorsoAngle > 50) {
          torsoScore -= (activeTorsoAngle - 50) * 1.5;
          _leanForwardFrames++;
          if (_leanForwardFrames > 15) _currentFeedback.add('身體太往前趴了，注意腰部！');
        } else {
          _leanForwardFrames = 0;
        }
        currentAccuracy += math.max(0.0, torsoScore);
      }

      // 2. 深蹲手臂角度 (20分)
      double armScore = 20.0;
      if (isSideFacing) {
        double activeArmAngle = ((leftElbow?.likelihood ?? 0) > (rightElbow?.likelihood ?? 0)) ? leftArmAngle : rightArmAngle;
        if (activeArmAngle < 30) armScore -= 5.0;
      } else {
        if (leftArmAngle < 30 || rightArmAngle < 30) armScore -= 5.0;
      }
      currentAccuracy += math.max(0.0, armScore);

      // 3. 深蹲膝蓋深度 (60分，佔比最高)
      double kneeScore = 60.0;
      double activeKneeAngle = isSideFacing ? 
        ((leftKnee?.likelihood ?? 0) > (rightKnee?.likelihood ?? 0) ? leftKneeAngle : rightKneeAngle) 
        : (leftKneeAngle + rightKneeAngle) / 2;
      
      if (activeKneeAngle < 60) {
        kneeScore -= (60 - activeKneeAngle) * 2.0; // 蹲太深
        _currentFeedback.add('蹲太深了，小心傷膝蓋！');
      } else if (activeKneeAngle > 175) {
        kneeScore -= (activeKneeAngle - 175) * 2.0; // 關節鎖死
      }
      currentAccuracy += math.max(0.0, kneeScore);

      // 4. 深蹲計次與怠速 (Rep Counting)
      if (activeKneeAngle < 120) {
        if (!_isSquattingDown) {
          _isSquattingDown = true;
          stepTaken = true;
        }
      } else if (activeKneeAngle > 160) {
        if (_isSquattingDown) {
          _isSquattingDown = false;
          _stepCount++; // 完成一次深蹲
          stepTaken = true;
        }
      }

      // 怠速判定 (4 秒)
      if (stepTaken) {
        _lastStepTime = DateTime.now();
        _standingStillFrames = 0;
      } else {
        DateTime referenceTime = _lastStepTime ?? _firstFrameTime!;
        if (DateTime.now().difference(referenceTime).inMilliseconds > 4000) {
          _standingStillFrames++;
          currentAccuracy -= 50.0;
          if (_standingStillFrames > 10) _currentFeedback.add('請繼續深蹲，不要停下來！');
        }
      }

    } else {
      // ==========================================
      // 🏃 超慢跑模式 (Slow Jogging)
      // ==========================================
      
      // 1. 軀幹前傾 (20分)
      if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
        double leftTorsoAngle = _calculateAngleWithVertical(leftShoulder, leftHip);
        double rightTorsoAngle = _calculateAngleWithVertical(rightShoulder, rightHip);
        double activeTorsoAngle = isSideFacing ?
            ((leftShoulder.likelihood + leftHip.likelihood) > (rightShoulder.likelihood + rightHip.likelihood) ? leftTorsoAngle : rightTorsoAngle)
            : (leftTorsoAngle + rightTorsoAngle) / 2;

        double torsoScore = 20.0;
        double maxTorso = isSideFacing ? 15.0 : 20.0; // 正面視覺前傾容錯度較高
        if (activeTorsoAngle > maxTorso) {
          torsoScore -= (activeTorsoAngle - maxTorso) * 1.5;
        }
        currentAccuracy += math.max(0.0, torsoScore);

        if (activeTorsoAngle > 25) {
          _leanForwardFrames++;
          if (_leanForwardFrames > 15) _currentFeedback.add('身體太前傾了，請挺直腰桿！');
        } else {
          _leanForwardFrames = 0;
        }
      }

      // 2. 手臂擺動 (40分)
      double calcArmScore(double angle) {
        double score = 20.0;
        if (isSideFacing) {
          // 🏃 跑步時手臂擺動，側面視角角度會從 60度(前擺) 到 140度(後擺) 劇烈變化
          // 因此只要不是完全下垂(>155)或夾死(<45)，都應視為合理擺動
          if (angle < 45) score -= (45 - angle) * 0.5;
          else if (angle > 155) score -= (angle - 155) * 0.8;
        } else {
          // 正面投影容錯放寬 20~160
          if (angle < 20) score -= (20 - angle) * 0.5;
          else if (angle > 160) score -= (angle - 160) * 0.8;
        }
        return math.max(0.0, score);
      }
      
      if (isSideFacing) {
        double leftArmConfidence = (leftElbow?.likelihood ?? 0) + (leftWrist?.likelihood ?? 0);
        double rightArmConfidence = (rightElbow?.likelihood ?? 0) + (rightWrist?.likelihood ?? 0);
        if (leftArmConfidence > rightArmConfidence) {
          currentAccuracy += calcArmScore(leftArmAngle) * 2;
        } else {
          currentAccuracy += calcArmScore(rightArmAngle) * 2;
        }
      } else {
        currentAccuracy += calcArmScore(leftArmAngle);
        currentAccuracy += calcArmScore(rightArmAngle);
      }

      // 3. 膝蓋微彎 (40分)
      double calcKneeScore(double angle, PoseLandmark? k) {
        double score = 20.0;
        // 🏃 跑步的動態週期中，腳踩地的「支撐腳」角度會非常接近 170~175度
        // 所以絕不能看到膝蓋直就扣分！只要不是立正鎖死(180)即可。
        double maxIdeal = 175.0; 
        if (k != null && k.likelihood < 0.7) maxIdeal = 179.0; // 長褲或模糊補償

        if (angle < 90) score -= (90 - angle) * 0.5;
        else if (angle > maxIdeal) score -= (angle - maxIdeal) * 2.0;
        return math.max(0.0, score);
      }
      
      if (isSideFacing) {
        if ((leftKnee?.likelihood ?? 0) > (rightKnee?.likelihood ?? 0)) {
          currentAccuracy += calcKneeScore(leftKneeAngle, leftKnee) * 2;
        } else {
          currentAccuracy += calcKneeScore(rightKneeAngle, rightKnee) * 2;
        }
      } else {
        currentAccuracy += calcKneeScore(leftKneeAngle, leftKnee);
        currentAccuracy += calcKneeScore(rightKneeAngle, rightKnee);
        
        // 🚨 防作弊：過濾掉「開合跳」、「側弓步」等雙腳張太開的非慢跑動作
        if (leftShoulder != null && rightShoulder != null && leftAnkle != null && rightAnkle != null) {
          double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
          double ankleWidth = (leftAnkle.x - rightAnkle.x).abs();
          if (shoulderWidth > 0 && ankleWidth > shoulderWidth * 1.5) {
            currentAccuracy -= 40.0; // 腳張太開直接重扣
            _currentFeedback.add('雙腳太開囉！超慢跑的步伐應該與肩同寬。');
          }
        }
      }

      // 4. 超慢跑計步與怠速 (1.5 秒)
      double yDiff = leftKnee!.y - rightKnee!.y;
      
      // 🎥 動態步伐門檻 (Dynamic Step Threshold)
      // 若影片人物較遠，15像素可能太大。改用軀幹長度的比例來判定 (約 8%)
      double torsoHeight = 100.0; // default
      if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null) {
         torsoHeight = ((leftShoulder.y + rightShoulder.y) / 2 - (leftHip.y + rightHip.y) / 2).abs();
      }
      double stepThreshold = math.max(4.0, torsoHeight * 0.08);

      if (yDiff < -stepThreshold) {
        if (!_isKneeHigh) {
          _stepCount++;
          _isKneeHigh = true;
          stepTaken = true;
        }
      } else if (yDiff > stepThreshold) {
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
          currentAccuracy -= 50.0;
          if (_standingStillFrames > 10) _currentFeedback.add('請保持動作，不要停下來喔！');
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
