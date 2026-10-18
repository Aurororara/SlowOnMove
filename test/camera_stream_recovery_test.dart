import 'dart:async';

// Native camera delivery is replaced to reproduce a successful start with zero frames.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_on_move/main.dart' as app;
import 'package:show_on_move/pose_detector_view.dart';

class SilentCamera extends CameraPlatform {
  int created = 0;
  final stopped = <int>[];
  final disposed = <int>[];
  Completer<void>? disposeGate;
  final frames = <int, StreamController<CameraImageData>>{};

  @override
  Future<int> createCamera(
          CameraDescription description, ResolutionPreset? resolutionPreset,
          {bool enableAudio = false}) async =>
      ++created;
  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(
          cameraId, 640, 480, ExposureMode.auto, false, FocusMode.auto, false));
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId,
      {CameraImageStreamOptions? options}) {
    final stream = StreamController<CameraImageData>(onCancel: () {
      stopped.add(cameraId);
    });
    frames[cameraId] = stream;
    return stream.stream;
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();
  @override
  Future<void> dispose(int cameraId) async {
    await disposeGate?.future;
    disposed.add(cameraId);
  }
}

void main() {
  late CameraPlatform oldPlatform;
  late SilentCamera camera;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    oldPlatform = CameraPlatform.instance;
    camera = SilentCamera();
    CameraPlatform.instance = camera;
    app.cameras = [
      const CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 90)
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('google_mlkit_pose_detector'),
            (_) async => null);
  });
  tearDown(() {
    CameraPlatform.instance = oldPlatform;
    debugDefaultTargetPlatformOverride = null;
    app.cameras = [];
  });

  testWidgets('Zero-frame streams rebuild twice then stop retrying',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PoseDetectorView(exerciseTitle: '深蹲')));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(camera.created, 1);
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
    }
    expect(camera.created, 3);
    expect(camera.stopped, [1, 2]);
    expect(camera.disposed, [1, 2]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('相機持續未傳入影格'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(camera.created, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(camera.disposed, [1, 2, 3]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Incoming frames prevent recovery; a later stall triggers it',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PoseDetectorView(exerciseTitle: '深蹲')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      // Unsupported format avoids ML Kit: this test concerns delivery only.
      camera.frames[1]!.add(const CameraImageData(
          format: CameraImageFormat(ImageFormatGroup.unknown, raw: -1),
          planes: [],
          height: 480,
          width: 640));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(camera.created, 1);
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(camera.created, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'Resume waits for old camera disposal and leaving cancels recovery',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: PoseDetectorView(exerciseTitle: '深蹲')));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    camera.disposeGate = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(camera.created, 1);
    camera.disposeGate!.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(camera.disposed, [1]);
    expect(camera.created, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(camera.created, 2);
    expect(camera.disposed, [1, 2]);
    debugDefaultTargetPlatformOverride = null;
  });
}
