import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
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
    _poseDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Future _startLiveFeed() async {
    if (_cameraIndex == -1 || cameras.isEmpty) return;
    final camera = cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) {
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
    if (_cameraController == null) return null;
    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
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
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

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
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() => _text = '');
    
    final poses = await _poseDetector.processImage(inputImage);
    
    // Analyze poses
    final analysisResult = _poseAnalyzer.analyze(poses);
    _accuracyRate = analysisResult.accuracy;
    
    // Smooth the feedback list to avoid flickering, just append latest
    for (var f in analysisResult.feedback) {
      if (!_feedback.contains(f)) {
         _feedback.add(f);
      }
    }
    _stepCount = analysisResult.stepCount;

    // Track for average
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
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false ||
        _cameraIndex == -1) {
      // In simulator or no camera, show a black background but still show the overlay
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  '相機不可用 (模擬器)',
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Simulate some progress
                    setState(() {
                      _elapsedSeconds = 900; // 15 mins
                      _accuracyRate = 92.5;
                      _stepCount = 1200;
                      _totalAccuracySum = 92.5;
                      _accuracySamples = 1;
                      _feedback = ['模擬動作：姿勢非常標準！', '維持呼吸。'];
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('生成模擬數據 (測試用)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
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
            // Time Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.exerciseTitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.white24),
            // Accuracy Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '準確率',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
            // Stop Button
            GestureDetector(
              onTap: () async {
                _timer?.cancel();
                _poseDetector.close();
                _cameraController?.dispose();
                
                double avgAcc = _accuracySamples > 0 ? (_totalAccuracySum / _accuracySamples) : 0.0;

                // Create and save training log to Firestore
                int caloriesBurned = ((_elapsedSeconds / 60.0) * 8.0).round();
                final log = TrainingLogModel(
                  memberId: 'test_user_001', // TODO: Replace with real Auth UID later
                  startTime: DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
                  endTime: DateTime.now(),
                  totalMins: _elapsedSeconds ~/ 60,
                  postureScore: avgAcc.round(),
                  calories: caloriesBurned,
                );
                
                // Fire and forget (don't block UI navigation)
                DataRepository().saveTrainingLog(log).then((_) {
                  debugPrint('Training log saved successfully to Firestore!');
                }).catchError((e) {
                  debugPrint('Failed to save training log: $e');
                });

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
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
