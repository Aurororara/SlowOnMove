import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ⭐ 已經匯入了
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:audioplayers/audioplayers.dart';
import 'main.dart';
import 'pose_painter.dart';
import 'pose_analyzer.dart';
import 'results_screen.dart';

class PoseDetectorView extends StatefulWidget {
  final String exerciseTitle;
  // 是否由「我的菜單」進入
  final bool fromWorkoutMenu;

  // 菜單目標，下一階段會拿來顯示進度
  final int? targetMinutes;
  final int? targetReps;

  const PoseDetectorView({
    super.key,
    this.exerciseTitle = '超慢跑',
    this.fromWorkoutMenu = false,
    this.targetMinutes,
    this.targetReps,
  });

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool get _supportsPoseDetectionPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ⭐ 網頁版不支援 PoseDetector，所以我們只在非網頁環境初始化它
  late final PoseDetector _poseDetector;
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;

  // 🔍 骨架偵測狀態 (用來判斷為什麼沒有骨架)
  // Count callbacks before platform checks or throttling to distinguish camera
  // delivery failures from image conversion / analysis failures in release builds.
  int _rawCameraFrames = 0;
  int _framesAtStreamStart = 0;
  int _streamStartAttempt = 0;
  DateTime? _lastCameraFrameAt;
  DateTime? _lastCameraFrameLogAt;
  String _cameraStreamStage = '等待相機初始化';
  String _cameraLifecycle = '啟動中';
  String? _cameraStreamError;
  int _framesReceived = 0; // 相機傳來的影格數
  int _inputImageFailures = 0; // 影像轉換失敗 (回傳 null) 的次數
  int _framesProcessed = 0; // 成功交給 ML Kit 處理的影格數
  int _framesWithPose = 0; // ML Kit 有偵測到人的影格數
  int _currentPoseCount = 0; // 最近一個影格偵測到的人數
  String? _lastDetectorError; // 最近一次 ML Kit 錯誤

  // 🦴 ML Kit 偶爾會掉幀，短暫保留上一次骨架避免閃爍消失
  List<Pose>? _lastPoses;
  DateTime? _lastPoseTime;
  static const Duration _poseHoldDuration = Duration(milliseconds: 800);
  CameraController? _cameraController;
  int _cameraIndex = -1;
  bool _isDisposingCamera = false;
  Future<void> _cameraOperations = Future<void>.value();
  Timer? _frameWatchdog;
  bool _cameraInForeground = true;
  int _cameraRecoveries = 0;

  // All native camera operations share one queue, including lifecycle changes.
  Future<void> _queueCameraOperation(Future<void> Function() operation) {
    _cameraOperations = _cameraOperations.then((_) async {
      await operation();
    }).catchError((Object error) {
      debugPrint('[Camera] 相機操作失敗：$error');
      if (mounted && !_isDisposingCamera) {
        setState(() => _cameraStreamError = error.toString());
      }
    });
    return _cameraOperations;
  }

  Future<void> _releaseCamera(CameraController controller) async {
    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        debugPrint('[Camera] 停止舊影格串流');
        await controller.stopImageStream();
        debugPrint('[Camera] 舊影格串流已停止');
      }
    } finally {
      debugPrint('[Camera] 釋放舊相機');
      await controller.dispose();
      debugPrint('[Camera] 舊相機已釋放');
    }
  }

  bool get _cameraShouldRun =>
      mounted && !_isDisposingCamera && _cameraInForeground;

  void _watchCameraFrames(CameraController controller) {
    _frameWatchdog?.cancel();
    final baseline = _rawCameraFrames;
    debugPrint('[Camera] 開始監測影格');
    _frameWatchdog = Timer(const Duration(seconds: 1), () {
      if (!_cameraShouldRun || !identical(controller, _cameraController)) {
        return;
      }
      if (_rawCameraFrames > baseline) {
        _watchCameraFrames(controller);
        return;
      }
      if (_cameraRecoveries >= 2) {
        setState(() => _cameraStreamError = '相機持續未傳入影格，請關閉運動頁後重試');
        return;
      }
      _cameraRecoveries++;
      _queueCameraOperation(() async {
        if (!_cameraShouldRun || !identical(controller, _cameraController)) {
          return;
        }
        setState(() {
          _cameraStreamStage = '未收到影格，正在重新建立相機 ($_cameraRecoveries/2)';
          _cameraController = null;
          _customPaint = null;
        });
        await _releaseCamera(controller);
        if (_cameraShouldRun) await _initializeCamera();
      });
    });
  }

  Timer? _timer;
  int _elapsedSeconds = 0;

  final PoseAnalyzer _poseAnalyzer = PoseAnalyzer();
  double _accuracyRate = 0.0;
  int _stepCount = 0;
  final List<String> _feedback = [];
  double _totalAccuracySum = 0.0;
  int _accuracySamples = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isBpmSoundEnabled = true;

  // ⚠️ 姿勢錯誤彈跳視窗相關狀態
  String? _currentErrorPopupMessage;
  Timer? _popupDismissTimer;
  late AnimationController _popupProgressController;
  DateTime? _lastPopupTriggerTime;

  void _startOrResumeBpmSound() async {
    if (widget.exerciseTitle != '超慢跑' || !_isBpmSoundEnabled) return;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/180_bpm_metronome.wav'));
    } catch (e) {
      debugPrint('Error playing BPM sound: $e');
    }
  }

  void _pauseOrStopBpmSound() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing BPM sound: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.exerciseTitle != '超慢跑') {
      _isBpmSoundEnabled = false;
    }
    WidgetsBinding.instance.addObserver(this);

    _popupProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // ⭐ 初始化 PoseDetector 前先檢查是否為網頁
    if (_supportsPoseDetectionPlatform) {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
    }

    if (!_supportsPoseDetectionPlatform) {
      _startTimer();
      return;
    }

    if (cameras
        .any((element) => element.lensDirection == CameraLensDirection.front)) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
            (element) => element.lensDirection == CameraLensDirection.front),
      );
    } else if (cameras.isNotEmpty) {
      _cameraIndex = 0;
    }
    _startLiveFeed();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  /// 顯示/更新姿勢錯誤彈跳視窗 (顯示 5 秒自動消失)
  void _showPostureErrorPopup(String message) {
    if (message.isEmpty) return;

    final now = DateTime.now();
    // 避免 1 秒內重複重置相同的訊息
    if (_currentErrorPopupMessage == message &&
        _lastPopupTriggerTime != null &&
        now.difference(_lastPopupTriggerTime!).inMilliseconds < 1000) {
      return;
    }

    _lastPopupTriggerTime = now;
    _popupDismissTimer?.cancel();

    if (mounted) {
      setState(() {
        _currentErrorPopupMessage = message;
      });
      _popupProgressController.stop();
      _popupProgressController.reset();
      _popupProgressController.forward();
    }

    // 設定 5 秒後自動隱藏視窗
    _popupDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _currentErrorPopupMessage = null;
        });
      }
    });
  }

  /// 手動關閉姿勢錯誤彈窗
  void _dismissPostureErrorPopup() {
    _popupDismissTimer?.cancel();
    _popupProgressController.stop();
    if (mounted) {
      setState(() {
        _currentErrorPopupMessage = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _popupDismissTimer?.cancel();
    _popupProgressController.dispose();
    _canProcess = false;
    _isDisposingCamera = true;

    _audioPlayer.stop();
    _audioPlayer.dispose();
    if (_supportsPoseDetectionPlatform) {
      _poseDetector.close();
    }
    _frameWatchdog?.cancel();
    _queueCameraOperation(() async {
      final controller = _cameraController;
      _cameraController = null;
      if (controller != null) await _releaseCamera(controller);
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(state);
    _cameraLifecycle = state.name;
    debugPrint('[Camera] 生命週期=${state.name}，'
        '串流=${_cameraController?.value.isStreamingImages}，'
        'canProcess=$_canProcess，busy=$_isBusy');

    if (_isDisposingCamera) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _cameraInForeground = false;
      _canProcess = false;
      _frameWatchdog?.cancel();
      _timer?.cancel();
      _pauseOrStopBpmSound();
      _queueCameraOperation(() async {
        final controller = _cameraController;
        if (mounted) {
          setState(() {
            _cameraController = null;
            _customPaint = null;
          });
        } else {
          _cameraController = null;
        }
        if (controller != null) await _releaseCamera(controller);
      });
    } else if (state == AppLifecycleState.resumed) {
      _cameraInForeground = true;
      _canProcess = true;
      _queueCameraOperation(() async {
        if (!_cameraShouldRun) return;
        if (_cameraController == null) await _initializeCamera();
        if (!_cameraShouldRun) return;
        _startTimer();
        _startOrResumeBpmSound();
      });
    }
  }

  Future<void> _startLiveFeed() => _queueCameraOperation(() async {
        await _initializeCamera();
        if (_cameraShouldRun) _startOrResumeBpmSound();
      });

  Future<void> _initializeCamera() async {
    if (!_supportsPoseDetectionPlatform || !_cameraShouldRun) return;
    if (_cameraIndex == -1 || cameras.isEmpty) return;
    debugPrint('[Camera] 建立相機');
    final controller = CameraController(
      cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _cameraController = controller;
    _cameraStreamError = null;
    _cameraStreamStage = '正在初始化相機';
    try {
      await controller.initialize();
      if (!_cameraShouldRun) return;
      await _startImageStreamWithDiagnostics(controller);
      if (!_cameraShouldRun) return;
      setState(() {});
    } catch (error) {
      if (identical(_cameraController, controller)) {
        _cameraController = null;
      }
      await _releaseCamera(controller);
      rethrow;
    }
  }

  Future<void> _startImageStreamWithDiagnostics(
      CameraController controller) async {
    final attempt = ++_streamStartAttempt;
    final framesAtStart = _rawCameraFrames;
    _framesAtStreamStart = framesAtStart;
    _cameraStreamStage = '啟動影格串流中';
    _cameraStreamError = null;
    debugPrint('[Camera] #$attempt 準備啟動串流');
    await controller.startImageStream((image) {
      if (!_cameraShouldRun || !identical(_cameraController, controller)) {
        return;
      }
      _processCameraImage(image);
    });
    if (!_cameraShouldRun) return;
    setState(() {
      _cameraStreamStage =
          _rawCameraFrames == framesAtStart ? '串流啟動呼叫完成，等待第一幀' : '相機影格已送入';
    });
    _watchCameraFrames(controller);
  }

  DateTime? _lastImageProcessTime;

  void _processCameraImage(CameraImage image) {
    // Keep this before every early return: preview alone is not proof that
    // the analysis callback has received a frame.
    final receivedAt = DateTime.now();
    _rawCameraFrames++;
    _lastCameraFrameAt = receivedAt;
    final isFirstFrame = _rawCameraFrames == _framesAtStreamStart + 1;
    _cameraStreamStage = '相機影格已送入';
    if (isFirstFrame ||
        _lastCameraFrameLogAt == null ||
        receivedAt.difference(_lastCameraFrameLogAt!).inSeconds >= 5) {
      _lastCameraFrameLogAt = receivedAt;
      debugPrint('[Camera] ${isFirstFrame ? "第一幀" : "影格回呼"}：'
          'raw=$_rawCameraFrames，${image.width}x${image.height}，'
          'format=${image.format.group.name}/${image.format.raw}，'
          'planes=${image.planes.length}，'
          'canProcess=$_canProcess，busy=$_isBusy');
    }
    if (isFirstFrame && mounted && !_isDisposingCamera) {
      setState(() {});
    }
    if (!_supportsPoseDetectionPlatform) return;

    final currentTime = DateTime.now();
    if (_lastImageProcessTime != null &&
        currentTime.difference(_lastImageProcessTime!).inMilliseconds < 100) {
      return; // 節流：限制在約 10 FPS (100ms)，大幅降低 AI 辨識 CPU/GPU 負載與耗電
    }
    _lastImageProcessTime = currentTime;

    _framesReceived++;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _inputImageFailures++;
      if (_inputImageFailures % 30 == 1) {
        debugPrint(
            '[Pose] 影像轉換失敗 (rotation/format/planes 不符) 累計 $_inputImageFailures 次');
      }
      return;
    }
    _processImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (!_supportsPoseDetectionPlatform || _cameraController == null) {
      return null;
    }

    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    // ⭐ 所有的 Platform 檢查都要包在 !kIsWeb 裡面
    if (_supportsPoseDetectionPlatform && Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (_supportsPoseDetectionPlatform && Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);

    // ⭐ 支援 Android 的 NV21, YUV_420_888 與 YV12，以及 iOS 的 BGRA8888, YUV420
    if (format == null ||
        (_supportsPoseDetectionPlatform &&
            Platform.isAndroid &&
            format != InputImageFormat.nv21 &&
            format != InputImageFormat.yuv_420_888 &&
            format != InputImageFormat.yv12) ||
        (_supportsPoseDetectionPlatform &&
            Platform.isIOS &&
            format != InputImageFormat.bgra8888 &&
            format != InputImageFormat.yuv420)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    // ⭐ 核心修復：Android NV21/YUV 必須將所有 planes 合併，不能只傳 plane[0]，否則 ML Kit 原生層會因為 Buffer 長度不足直接回傳 0 隻骨架
    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes[0].bytes;
    } else {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_supportsPoseDetectionPlatform || !_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      final poses = await _poseDetector.processImage(inputImage);

      _framesProcessed++;
      _currentPoseCount = poses.length;
      _lastDetectorError = null;

      // 掉幀時沿用上一次骨架 (最多 800ms)，有偵測到就更新
      List<Pose> displayPoses = poses;
      final nowForHold = DateTime.now();
      if (poses.isNotEmpty) {
        _framesWithPose++;
        _lastPoses = poses;
        _lastPoseTime = nowForHold;
      } else if (_lastPoses != null &&
          _lastPoseTime != null &&
          nowForHold.difference(_lastPoseTime!) < _poseHoldDuration) {
        displayPoses = _lastPoses!;
      }

      if (_framesProcessed % 30 == 0) {
        debugPrint(
            '[Pose] 收到 $_framesReceived 幀 / 轉換失敗 $_inputImageFailures / 處理 $_framesProcessed / 有偵測到人 $_framesWithPose / 目前 ${poses.length} 人');
      }

      // 分析若拋出例外，不可影響骨架繪製
      try {
        final analysisResult =
            _poseAnalyzer.analyze(poses, exerciseType: widget.exerciseTitle);
        _accuracyRate = analysisResult.accuracy;

        for (var f in analysisResult.feedback) {
          if (!_feedback.contains(f)) {
            _feedback.add(f);
          }
        }
        _stepCount = analysisResult.stepCount;

        // 🚨 當姿勢分析回傳錯誤提醒時，觸發 5 秒自動消失的彈跳視窗
        if (analysisResult.feedback.isNotEmpty) {
          final postureErrors =
              analysisResult.feedback.where((msg) => msg != '請站在鏡頭前').toList();
          if (postureErrors.isNotEmpty) {
            _showPostureErrorPopup(postureErrors.first);
          }
        }

        if (poses.isNotEmpty) {
          _totalAccuracySum += _accuracyRate;
          _accuracySamples++;
        }
      } catch (e) {
        debugPrint('姿勢分析異常 (已略過，仍繪製骨架): $e');
      }

      if (inputImage.metadata?.size != null &&
          inputImage.metadata?.rotation != null) {
        final painter = PosePainter(
          displayPoses,
          inputImage.metadata!.size,
          inputImage.metadata!.rotation,
          cameras[_cameraIndex].lensDirection,
        );
        _customPaint = CustomPaint(painter: painter);
      } else {
        _customPaint = null;
      }
    } catch (e) {
      _lastDetectorError = e.toString();
      debugPrint('Pose detection 處理異常: $e');
    } finally {
      // 確保即使中途有任何例外，_isBusy 一定會解鎖，不會永久卡死在 0
      _isBusy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsPoseDetectionPlatform) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text(
                kIsWeb ? '網頁版目前不支援 AI 動作偵測' : '桌面版目前不支援 AI 動作偵測',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                kIsWeb ? '請使用安卓模擬器或實體手機測試' : '請改用 iPhone、Android 或模擬器測試',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              )
            ],
          ),
        ),
      );
    }

    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false ||
        _cameraIndex == -1) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '相機啟動中...',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      _startOrResumeBpmSound();
                      setState(() {
                        _elapsedSeconds = 300; // 5 minutes mock
                        _accuracyRate = 92.5;
                        _stepCount = 1200;
                        _feedback.add("模擬運動數據生成成功！這是一次超慢跑測試。");
                      });
                      _showPostureErrorPopup("膝蓋抬太高了！超慢跑只需微微抬腳，不要變成高抬腿喔。");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('模擬數據已生成（並觸發 5 秒姿勢彈窗）')),
                      );
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('生成模擬數據 (測試 5秒彈窗)'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            _buildDetectionOverlay(),
            _buildPoseStatusChip(),
            _buildPostureErrorPopup(),
          ],
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_cameraController!),
            ),
          ),
          if (_customPaint != null) _customPaint!,
          _buildDetectionOverlay(),
          _buildPoseStatusChip(),
          _buildPostureErrorPopup(),
        ],
      ),
    );
  }

  int? get _targetSeconds {
    if (!widget.fromWorkoutMenu) {
      return null;
    }

    final targetMinutes = widget.targetMinutes;

    if (targetMinutes == null || targetMinutes <= 0) {
      return null;
    }

    return targetMinutes * 60;
  }

  String get _elapsedTimeText {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');

    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String get _workoutProgressText {
    // 一般運動模式：完全維持原本顯示
    if (!widget.fromWorkoutMenu) {
      return _elapsedTimeText;
    }

    // 菜單模式：深蹲
    if (widget.exerciseTitle == '深蹲') {
      final targetReps = widget.targetReps;

      if (targetReps == null || targetReps <= 0) {
        return '$_stepCount 下';
      }

      return '$_stepCount / $targetReps 下';
    }

    // 菜單模式：超慢跑
    final targetSeconds = _targetSeconds;

    if (targetSeconds == null) {
      return _elapsedTimeText;
    }

    final targetMinutes = (targetSeconds ~/ 60).toString().padLeft(2, '0');

    final targetRemainSeconds = (targetSeconds % 60).toString().padLeft(2, '0');

    return '$_elapsedTimeText / '
        '$targetMinutes:$targetRemainSeconds';
  }

  double? get _workoutTargetProgress {
    if (!widget.fromWorkoutMenu) {
      return null;
    }

    if (widget.exerciseTitle == '深蹲') {
      final targetReps = widget.targetReps;

      if (targetReps == null || targetReps <= 0) {
        return null;
      }

      return (_stepCount / targetReps).clamp(0.0, 1.0).toDouble();
    }

    final targetSeconds = _targetSeconds;

    if (targetSeconds == null || targetSeconds <= 0) {
      return null;
    }

    return (_elapsedSeconds / targetSeconds).clamp(0.0, 1.0).toDouble();
  }

  bool get _isWorkoutTargetReached {
    if (!widget.fromWorkoutMenu) {
      return false;
    }

    if (widget.exerciseTitle == '深蹲') {
      final targetReps = widget.targetReps;

      if (targetReps == null || targetReps <= 0) {
        return false;
      }

      return _stepCount >= targetReps;
    }

    final targetSeconds = _targetSeconds;

    if (targetSeconds == null || targetSeconds <= 0) {
      return false;
    }

    return _elapsedSeconds >= targetSeconds;
  }

  Future<void> _finishExercise() async {
    _timer?.cancel();

    await _audioPlayer.stop();

    await _disposeCameraSafely();

    final double avgAcc =
        _accuracySamples > 0 ? _totalAccuracySum / _accuracySamples : 0.0;

    if (!mounted) return;

    // 菜單模式
    if (widget.fromWorkoutMenu) {
      final bool? completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            timeSeconds: _elapsedSeconds,
            averageAccuracy: avgAcc,
            stepCount: _stepCount,
            finalFeedback: _feedback,
            exerciseTitle: widget.exerciseTitle,
            fromWorkoutMenu: true,
          ),
        ),
      );

      if (!mounted) return;

      if (completed == true) {
        Navigator.pop(
          context,
          true,
        );
      }

      return;
    }

    // 一般運動模式
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          timeSeconds: _elapsedSeconds,
          averageAccuracy: avgAcc,
          stepCount: _stepCount,
          finalFeedback: _feedback,
          exerciseTitle: widget.exerciseTitle,
          fromWorkoutMenu: false,
        ),
      ),
    );
  }

  Future<void> _disposeCameraSafely() async {
    if (_isDisposingCamera) {
      return;
    }

    _isDisposingCamera = true;
    _canProcess = false;

    _frameWatchdog?.cancel();
    await _queueCameraOperation(() async {
      final controller = _cameraController;
      if (mounted) {
        setState(() => _cameraController = null);
      } else {
        _cameraController = null;
      }
      if (controller != null) await _releaseCamera(controller);
    });
  }

  /// 顯示骨架偵測目前卡在哪個階段 (除錯用，確認後可移除)
  Widget _buildPoseStatusChip() {
    String text;
    Color color;

    if (_cameraStreamError != null) {
      text = '最近串流錯誤：$_cameraStreamError';
      color = Colors.redAccent;
    } else if (_lastDetectorError != null) {
      text = 'ML Kit 錯誤：$_lastDetectorError';
      color = Colors.redAccent;
    } else if (!_canProcess) {
      text = '影像分析已暫停';
      color = Colors.orangeAccent;
    } else if (_framesReceived == 0) {
      text = _rawCameraFrames == 0 ? _cameraStreamStage : '相機已有回呼，但尚未進入影像轉換';
      color = Colors.orangeAccent;
    } else if (_framesProcessed == 0) {
      if (_inputImageFailures == _framesReceived) {
        text = '影像轉換失敗 ($_inputImageFailures 次)，無法交給 ML Kit';
        color = Colors.redAccent;
      } else {
        text = _isBusy ? 'ML Kit 首次處理中' : '等待 ML Kit 處理影格';
        color = Colors.orangeAccent;
      }
    } else if (_currentPoseCount == 0) {
      text = 'ML Kit 未偵測到人 (請讓全身入鏡、光線充足)';
      color = Colors.orangeAccent;
    } else {
      text = '已偵測到人';
      color = Colors.greenAccent;
    }

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$text\n原始回呼 $_rawCameraFrames｜分析取樣 $_framesReceived｜'
              '處理 $_framesProcessed｜轉換失敗 $_inputImageFailures｜'
              '最近影格 ${_lastCameraFrameAt == null ? "尚無" : "${DateTime.now().difference(_lastCameraFrameAt!).inSeconds} 秒前"}'
              '｜$_cameraLifecycle',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.exerciseTitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _workoutProgressText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.fromWorkoutMenu ? 21 : 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white24,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '準確率',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_accuracyRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _accuracyRate > 80
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.exerciseTitle == '超慢跑') ...[
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isBpmSoundEnabled = !_isBpmSoundEnabled;

                          if (_isBpmSoundEnabled) {
                            _startOrResumeBpmSound();
                          } else {
                            _pauseOrStopBpmSound();
                          }
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isBpmSoundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: _isBpmSoundEnabled
                                ? Colors.amberAccent
                                : Colors.white38,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isBpmSoundEnabled ? '180 BPM' : '靜音',
                            style: TextStyle(
                              color: _isBpmSoundEnabled
                                  ? Colors.amberAccent
                                  : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white24,
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                  ),
                  child: GestureDetector(
                    onTap: _finishExercise,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 注意：進度條一定要在 Row 外面
            if (_workoutTargetProgress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _workoutTargetProgress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.greenAccent,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ],

            if (_isWorkoutTargetReached) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '目標已達成，可以結束這項訓練',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 根據 AI 反饋拆解出「姿勢問題標題」與「💡 具體改進建議」
  Map<String, String> _getImprovementTip(String message) {
    if (message.contains('前傾') || message.contains('前趴')) {
      return {
        'title': '軀幹過度前傾',
        'tip': '請將重心稍往後移，收緊核心，保持背部與腰部自然挺直。',
      };
    }
    if (message.contains('蹲太深')) {
      return {
        'title': '深蹲深度過深',
        'tip': '膝蓋彎曲請控制在 90 度左右（大腿與地面平行），避免超過膝關節健康負擔。',
      };
    }
    if (message.contains('膝蓋內扣')) {
      return {
        'title': '膝蓋往內扣',
        'tip': '下蹲時請將膝蓋微外展，保持膝蓋與腳尖方向一致，保護膝關節。',
      };
    }
    if (message.contains('太窄')) {
      return {
        'title': '站姿腳距過窄',
        'tip': '請將雙腳稍微往外移，調整至雙腳與肩同寬。',
      };
    }
    if (message.contains('太開')) {
      return {
        'title': '站姿腳距過寬',
        'tip': '請縮小站距，保持雙腳與肩同寬或略寬即可。',
      };
    }
    if (message.contains('雙手') || message.contains('手臂')) {
      return {
        'title': '手臂擺放位置不當',
        'tip': '請將雙手向前平舉或置於胸前，幫助身體維持核心平衡。',
      };
    }
    if (message.contains('抬太高') || message.contains('高抬腿')) {
      return {
        'title': '超慢跑膝蓋抬過高',
        'tip': '超慢跑講求小步幅、高步頻，腳離地僅需 1~2 公分即可，避免過度抬膝。',
      };
    }
    if (message.contains('腳跟重落地') || message.contains('腳跟')) {
      return {
        'title': '腳跟重落地',
        'tip': '請以前腳掌或全腳掌輕盈著地，利用踝關節彈性避震，避免膝蓋承受衝擊。',
      };
    }
    if (message.contains('停下來') || message.contains('保持動作')) {
      return {
        'title': '動作停頓提醒',
        'tip': '請保持規律的運動節奏，不要停下來喔，加油！',
      };
    }

    return {
      'title': '姿勢需要調整',
      'tip': message,
    };
  }

  /// ⚠️ 姿勢錯誤改進建議彈跳視窗 (顯示5秒後自動消失)
  Widget _buildPostureErrorPopup() {
    if (_currentErrorPopupMessage == null) return const SizedBox.shrink();

    final tipInfo = _getImprovementTip(_currentErrorPopupMessage!);

    return Positioned(
      top: 185,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _currentErrorPopupMessage != null ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade900.withOpacity(0.95),
                Colors.amber.shade900.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.amberAccent.withOpacity(0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.amberAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  '⚠️ 姿勢改進提醒',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '(5秒後自動消失)',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tipInfo['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '💡 改進建議：${tipInfo['tip']!}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13.5,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        onPressed: _dismissPostureErrorPopup,
                        tooltip: '關閉提醒',
                      ),
                    ],
                  ),
                ),
                // 5 秒倒數進度條
                AnimatedBuilder(
                  animation: _popupProgressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: 1.0 - _popupProgressController.value,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.amberAccent,
                      ),
                      minHeight: 4,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
