import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:show_on_move/community/pose/group_pose_analyzer.dart';
import 'package:show_on_move/community/pose/captured_frame_info.dart';
import 'package:show_on_move/community/pose/group_pose_frame.dart';
import 'package:show_on_move/community/pose/group_pose_painter.dart';

class _Detector extends PoseDetector {
  List<Pose> poses;
  Object? failure;
  int calls = 0;
  bool closed = false;
  _Detector(this.poses) : super(options: PoseDetectorOptions());

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async {
    calls++;
    expect(await File(inputImage.filePath!).exists(), isTrue);
    if (failure != null) throw failure!;
    return poses;
  }

  @override
  Future<void> close() async => closed = true;
}

ByteBuffer _frame() {
  final png = Uint8List(24);
  png.setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
  png.setAll(12, [73, 72, 68, 82]);
  final header = ByteData.sublistView(png);
  header.setUint32(16, 160);
  header.setUint32(20, 240);
  return png.buffer;
}

Pose _body({double confidence = 1}) => Pose(landmarks: {
      for (final type in PoseLandmarkType.values)
        type: PoseLandmark(
            type: type,
            x: type.index.isEven ? 100 : 60,
            y: type.index < 17
                ? 40
                : type.index < 25
                    ? 110
                    : type.index < 27
                        ? 170
                        : 220,
            z: 0,
            likelihood: confidence),
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Both iOS PNG and Android JPEG snapshots retain upright dimensions', () {
    expect(capturedFrameInfo(_frame().asUint8List()),
        (width: 160, height: 240, extension: 'png'));
    final jpeg = Uint8List.fromList([
      255,
      216,
      255,
      224,
      0,
      4,
      0,
      0,
      255,
      192,
      0,
      11,
      8,
      0,
      240,
      0,
      160,
      1,
      1,
      17,
      0,
      255,
      217,
    ]);
    expect(
        capturedFrameInfo(jpeg), (width: 160, height: 240, extension: 'jpg'));
    expect(() => capturedFrameInfo(jpeg.sublist(0, 12)), throwsFormatException);
    expect(() => capturedFrameInfo(Uint8List(24)), throwsFormatException);
  });

  test(
      'Full pose packet fits lossy transport and ages without clock synchronization',
      () {
    final now = DateTime(2026, 10, 18);
    final frame = GroupPoseFrame(
      status: GroupPoseStatus.tracking,
      score: 83.4,
      aspectRatio: 9 / 16,
      sampledAt: now.subtract(const Duration(milliseconds: 1500)),
      points: [
        for (final id in groupPoseJointIds)
          GroupPosePoint(id, .1234, .5678, .99)
      ],
      feedback: List.filled(40, '請').join(),
    );
    final bytes = frame.encode(7, now);
    expect(bytes.length, lessThanOrEqualTo(1200));
    final packet = GroupPoseFrame.decode(bytes, now)!;
    expect(packet.sequence, 7);
    expect(packet.frame.score, 83.4);
    expect(packet.frame.points.length, groupPoseJointIds.length);
    expect(packet.frame.canDisplayScore(now), isTrue);
    expect(
        packet.frame
            .canDisplayScore(now.add(const Duration(milliseconds: 501))),
        isFalse);
  });

  test(
      'Malformed packets cannot produce scores or unbounded overlay coordinates',
      () {
    final now = DateTime.now();
    final valid = GroupPoseFrame(
        status: GroupPoseStatus.tracking,
        score: 0,
        points: const [GroupPosePoint(11, .5, .5, 1)]).encode(1, now);
    expect(
        GroupPoseFrame.decode(valid, now)!.frame.canDisplayScore(now), isTrue);
    for (final change in <Map<String, dynamic>>[
      {'score': 101},
      {'score': null},
      {'ratio': 0},
      {'age': -1},
      {'status': 'paused'},
      {'v': 2},
      {'seq': -1},
      {
        'points': [
          [11, 10000, .5, 1]
        ]
      },
      {
        'points': [
          [11, .5, .5, 1],
          [11, .5, .5, 1]
        ]
      },
      {
        'points': [
          [999, .5, .5, 1]
        ]
      },
    ]) {
      final data = jsonDecode(utf8.decode(valid)) as Map<String, dynamic>;
      data.addAll(change);
      expect(GroupPoseFrame.decode(utf8.encode(jsonEncode(data)), now), isNull,
          reason: change.toString());
    }
    expect(GroupPoseFrame.decode(List.filled(1201, 0), now), isNull);
    expect(GroupPoseFrame.decode([255, 255], now), isNull);
  });

  test('Overlay follows contain letterboxing rather than stretching to tile',
      () async {
    final recorder = ui.PictureRecorder();
    final frame = GroupPoseFrame(
        status: GroupPoseStatus.tracking,
        score: 90,
        aspectRatio: 9 / 16,
        points: const [
          GroupPosePoint(11, 0, .5, 1),
          GroupPosePoint(12, 1, .5, 1),
        ]);
    GroupPosePainter(frame).paint(Canvas(recorder), const Size(200, 100));
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 100);
    final pixels = (await image.toByteData())!;
    expect(pixels.getUint8((50 * 200 + 100) * 4 + 3), greaterThan(0));
    expect(pixels.getUint8((50 * 200 + 40) * 4 + 3), 0);
    image.dispose();
    picture.dispose();
  });

  test(
      'Existing track sample yields a real score; missing bodies clear it; no files remain',
      () async {
    final directory = await Directory.systemTemp.createTemp('group_pose_test_');
    final detector = _Detector([_body()]);
    final analyzer = GroupPoseAnalyzer(
        exerciseTitle: '超慢跑',
        detector: detector,
        temporaryDirectory: () async => directory);
    try {
      final result = await analyzer.sample(() async => _frame());
      expect(result.status, GroupPoseStatus.tracking);
      expect(result.score, inInclusiveRange(0, 100));
      expect(result.aspectRatio, 160 / 240);
      expect(result.points.length, groupPoseJointIds.length);
      expect(
          await directory.list(recursive: true).where((p) => p is File).length,
          0);
      detector.poses = [];
      final lost = await analyzer.sample(() async => _frame());
      expect(lost.status, GroupPoseStatus.noPose);
      expect(lost.score, isNull);
      expect(lost.points, isEmpty);
      detector.poses = [_body(confidence: .1)];
      expect((await analyzer.sample(() async => _frame())).score, isNull);
      detector.failure = StateError('ML Kit failed');
      expect((await analyzer.sample(() async => _frame())).status,
          GroupPoseStatus.error);
      expect(
          await directory.list(recursive: true).where((p) => p is File).length,
          0);
    } finally {
      await analyzer.close();
      expect(detector.closed, isTrue);
      expect(await directory.list().length, 0);
      await directory.delete(recursive: true);
    }
  });

  test(
      'Sampling is serialized and closing an active sample cannot publish a new score',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('group_pose_serial_');
    final detector = _Detector([_body()]);
    final analyzer = GroupPoseAnalyzer(
        exerciseTitle: '深蹲',
        detector: detector,
        temporaryDirectory: () async => directory);
    final capture = Completer<ByteBuffer>();
    var captures = 0;
    Future<ByteBuffer> getFrame() {
      captures++;
      return capture.future;
    }

    final first = analyzer.sample(getFrame);
    final second = analyzer.sample(getFrame);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(captures, 1);
    final closing = analyzer.close();
    capture.complete(_frame());
    expect((await first).status, GroupPoseStatus.error);
    expect((await second).score, isNull);
    await closing;
    expect(detector.calls, 0);
    expect(detector.closed, isTrue);
    await directory.delete(recursive: true);
  });
}
