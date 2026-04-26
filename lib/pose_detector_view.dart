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
import 'models/training_log_model.dart';
import 'repositories/data_repository.dart';

class PoseDetectorView extends StatefulWidget {
  final String exerciseTitle;
  const PoseDetectorView({super.key, this.exerciseTitle = '超慢跑'});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  // ⭐ 網頁版不支援 PoseDetector，所以我們只在非網頁環境初始化它
  late final PoseDetector _poseDetector;
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  CameraController? _cameraController;
  int _cameraIndex = -1;

  Timer? _timer;
  int _elapsedSeconds = 0;
  
  final PoseAnalyzer _poseAnalyzer = PoseAnalyzer();
  double _accuracyRate = 0.0;
  int _stepCount = 0;
  List<String> _feedback = [];
  double _totalAccuracySum = 0.0;
  int _accuracySamples = 0;

  @override
  void initState() {
    super.initState();
    
    // ⭐ 初始化 PoseDetector 前先檢查是否為網頁
    if (!kIsWeb) {
      _poseDetector = PoseDetector(options: PoseDetectorOptions());
    }

    if (cameras.any((element) => element.lensDirection == CameraLensDirection.front)) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere((element) => element.lensDirection == CameraLensDirection.front),
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
    if (!kIsWeb) {
      _poseDetector.close();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  Future _startLiveFeed() async {
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

  void _processCameraImage(CameraImage image) {
    if (kIsWeb) return; // 網頁版不執行
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
    if (kIsWeb || _cameraController == null) return null; // ⭐ 網頁版直接跳過

    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    // ⭐ 所有的 Platform 檢查都要包在 !kIsWeb 裡面
    if (!kIsWeb && Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (!kIsWeb && Platform.isAndroid) {
      var rotationCompensation = _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    
    // ⭐ 這裡也是：檢查 Platform 前先確定不是 Web
    if (format == null ||
        (!kIsWeb && Platform.isAndroid && format != InputImageFormat.nv21) ||
        (!kIsWeb && Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

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
    if (kIsWeb || !_canProcess || _isBusy) return; // ⭐ 網頁版不執行
    _isBusy = true;
    setState(() => _text = '');
    
    final poses = await _poseDetector.processImage(inputImage);
    
    final analysisResult = _poseAnalyzer.analyze(poses);
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

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        cameras[_cameraIndex].lensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ 如果是網頁版，顯示一個友善提示
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text(
                '網頁版目前不支援 AI 動作偵測',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                '請使用安卓模擬器或實體手機測試',
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
            const Center(
              child: Text(
                '相機啟動中...',
                style: TextStyle(color: Colors.white54),
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
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.white24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('準確率', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${_accuracyRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _accuracyRate > 80 ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () async {
                _timer?.cancel();
                if (!kIsWeb) _poseDetector.close();
                _cameraController?.dispose();
                
                double avgAcc = _accuracySamples > 0 ? (_totalAccuracySum / _accuracySamples) : 0.0;
                int caloriesBurned = ((_elapsedSeconds / 60.0) * 8.0).round();

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
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}