import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ⭐ 已經匯入了
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'main.dart';
import 'pose_painter.dart';
import 'pose_analyzer.dart';
import 'results_screen.dart';

class PoseDetectorView extends StatefulWidget {
  final String exerciseTitle;
  const PoseDetectorView({super.key, this.exerciseTitle = '超慢跑'});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  bool get _supportsPoseDetectionPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ⭐ 網頁版不支援 PoseDetector，所以我們只在非網頁環境初始化它
  late final PoseDetector _poseDetector;
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  CameraController? _cameraController;
  int _cameraIndex = -1;

  Timer? _timer;
  int _elapsedSeconds = 0;

  final PoseAnalyzer _poseAnalyzer = PoseAnalyzer();
  double _accuracyRate = 0.0;
  int _stepCount = 0;
  final List<String> _feedback = [];
  double _totalAccuracySum = 0.0;
  int _accuracySamples = 0;

  @override
  void initState() {
    super.initState();

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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _canProcess = false;
    if (_supportsPoseDetectionPlatform) {
      _poseDetector.close();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  Future _startLiveFeed() async {
    if (!_supportsPoseDetectionPlatform) return;
    if (_cameraIndex == -1 || cameras.isEmpty) return;
    final camera = cameras[_cameraIndex];

    // ⭐ 這裡改動了：Platform 檢查前先加上 !kIsWeb
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: (!kIsWeb && Platform.isAndroid)
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      // ⭐ 只有非網頁版才去跑影像串流偵測，因為網頁版跑不動 ML Kit
      if (!kIsWeb) {
        _cameraController?.startImageStream(_processCameraImage);
      }
      setState(() {});
    });
  }

  DateTime? _lastImageProcessTime;

  void _processCameraImage(CameraImage image) {
    if (!_supportsPoseDetectionPlatform) return;

    final currentTime = DateTime.now();
    if (_lastImageProcessTime != null &&
        currentTime.difference(_lastImageProcessTime!).inMilliseconds < 60) {
      return; // 節流：限制在約 15 FPS，減少 CPU 負載與發熱
    }
    _lastImageProcessTime = currentTime;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
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

    // ⭐ 這裡也是：檢查 Platform 前先確定不是 Web
    if (format == null ||
        (_supportsPoseDetectionPlatform &&
            Platform.isAndroid &&
            format != InputImageFormat.nv21) ||
        (_supportsPoseDetectionPlatform &&
            Platform.isIOS &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
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
    setState(() {});

    final poses = await _poseDetector.processImage(inputImage);

    final analysisResult =
        _poseAnalyzer.analyze(poses, exerciseType: widget.exerciseTitle);
    _accuracyRate = analysisResult.accuracy;

    for (var f in analysisResult.feedback) {
      if (!_feedback.contains(f)) {
        _feedback.add(f);
      }
    }
    _stepCount = analysisResult.stepCount;

    if (poses.isNotEmpty) {
      _totalAccuracySum += _accuracyRate;
      _accuracySamples++;
    }

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        cameras[_cameraIndex].lensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) setState(() {});
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
                      setState(() {
                        _elapsedSeconds = 300; // 5 minutes mock
                        _accuracyRate = 92.5;
                        _stepCount = 1200;
                        _feedback.add("模擬運動數據生成成功！這是一次超慢跑測試。");
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('模擬數據已生成')),
                      );
                    },
                    icon: const Icon(Icons.bug_report),
                    label: const Text('生成模擬數據 (測試用)'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            _buildDetectionOverlay(),
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
        ],
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    final String minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.exerciseTitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.white24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('準確率',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${_accuracyRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _accuracyRate > 80
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () async {
                _timer?.cancel();
                if (_supportsPoseDetectionPlatform) _poseDetector.close();
                _cameraController?.dispose();

                double avgAcc = _accuracySamples > 0
                    ? (_totalAccuracySum / _accuracySamples)
                    : 0.0;
                // 導向結果頁
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultsScreen(
                        timeSeconds: _elapsedSeconds,
                        averageAccuracy: avgAcc,
                        stepCount: _stepCount,
                        finalFeedback: _feedback,
                        exerciseTitle: widget.exerciseTitle,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
