import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../../pose_analyzer.dart';
import 'group_pose_frame.dart';
import 'captured_frame_info.dart';

/// Samples the already-published WebRTC track. Never owns or opens a camera.
class GroupPoseAnalyzer {
  final String exerciseTitle;
  final PoseDetector _detector;
  final PoseAnalyzer _analyzer = PoseAnalyzer();
  final Future<Directory> Function() _temporaryDirectory;
  Directory? _workingDirectory;
  Future<GroupPoseFrame>? _processing;
  bool _capturePending = false;
  bool _closed = false;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  GroupPoseAnalyzer(
      {required this.exerciseTitle,
      PoseDetector? detector,
      Future<Directory> Function()? temporaryDirectory})
      : _detector = detector ?? PoseDetector(options: PoseDetectorOptions()),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  Future<GroupPoseFrame> sample(Future<ByteBuffer> Function() captureFrame) {
    if (_closed) return Future.error(StateError('Pose analyzer closed'));
    if (_processing != null) return _processing!;
    final future = _sample(captureFrame);
    _processing = future;
    return future.whenComplete(() => _processing = null);
  }

  Future<GroupPoseFrame> _sample(
      Future<ByteBuffer> Function() captureFrame) async {
    final sampledAt = DateTime.now();
    if (_capturePending) {
      return GroupPoseFrame(
          status: GroupPoseStatus.error, feedback: '正在等待視訊影格，請重新開啟相機。');
    }
    File? imageFile;
    try {
      final temp = await _temporaryDirectory();
      if (_closed) throw StateError('Pose analyzer closed');
      _workingDirectory ??= await temp.createTemp('group_pose_');
      // flutter_webrtc captureFrame rotates captured images upright.
      // Do not overlap captures: its native API uses a shared captureFrame.png.
      _capturePending = true;
      final capture =
          Future<ByteBuffer>.sync(captureFrame).then((buffer) async {
        try {
          final nativeSnapshot = File('${temp.path}/captureFrame.png');
          if (await nativeSnapshot.exists()) await nativeSnapshot.delete();
        } finally {
          _capturePending = false;
        }
        return buffer;
      }, onError: (Object error, StackTrace stack) {
        _capturePending = false;
        Error.throwWithStackTrace(error, stack);
      });
      final buffer = await capture.timeout(const Duration(seconds: 2));
      if (_closed) throw StateError('Pose analyzer closed');
      final bytes = buffer.asUint8List();
      final info = capturedFrameInfo(bytes);
      final width = info.width;
      final height = info.height;
      imageFile = File('${_workingDirectory!.path}/frame.${info.extension}');
      await imageFile.writeAsBytes(bytes, flush: false);
      final poses =
          await _detector.processImage(InputImage.fromFilePath(imageFile.path));
      if (_closed) throw StateError('Pose analyzer closed');
      // A partial/occluded body must not become a convincing score of zero.
      const leftSide = [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle
      ];
      const rightSide = [
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle
      ];
      bool visibleSide(List<PoseLandmarkType> side) =>
          poses.isNotEmpty &&
          side.every(
              (type) => (poses.first.landmarks[type]?.likelihood ?? 0) >= 0.35);
      if (!visibleSide(leftSide) && !visibleSide(rightSide)) {
        return GroupPoseFrame(
            status: GroupPoseStatus.noPose,
            feedback: '請讓肩膀與雙腳完整入鏡。',
            sampledAt: sampledAt);
      }
      final result = _analyzer.analyze(poses, exerciseType: exerciseTitle);
      if (!result.accuracy.isFinite) {
        throw const FormatException('Invalid pose score');
      }
      final points = poses.first.landmarks.values
          .where((p) =>
              groupPoseJointIds.contains(p.type.index) &&
              p.x.isFinite &&
              p.y.isFinite &&
              p.likelihood.isFinite)
          .map((p) => GroupPosePoint(p.type.index, (p.x / width).clamp(-1, 2),
              (p.y / height).clamp(-1, 2), p.likelihood.clamp(0, 1)))
          .toList();
      return GroupPoseFrame(
          status: GroupPoseStatus.tracking,
          score: result.accuracy.clamp(0, 100),
          aspectRatio: width / height,
          points: points,
          feedback: result.feedback.isEmpty ? '' : result.feedback.first,
          sampledAt: sampledAt);
    } catch (error) {
      debugPrint('[GroupPose] $error');
      return GroupPoseFrame(
          status: GroupPoseStatus.error, feedback: '姿勢分析暫時無法使用，可重開相機再試。');
    } finally {
      try {
        if (imageFile != null && await imageFile.exists()) {
          await imageFile.delete();
        }
      } on FileSystemException {
        debugPrint('[GroupPose] 暫存影格將在離開房間時再次清理。');
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _processing;
    try {
      await _detector.close();
    } finally {
      final directory = _workingDirectory;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}
