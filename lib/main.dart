import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

import 'login_screen.dart';

List<CameraDescription> cameras = [];

bool get _supportsCameraInitialization =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('--- App Starting ---');

  // Facebook Web 初始化
  if (kIsWeb) {
    await FacebookAuth.i.webAndDesktopInitialize(
      appId: '1486365623030140',
      cookie: true,
      xfbml: true,
      version: 'v19.0',
    );
  }

  // LINE Login 初始化（僅支援 Android / iOS）
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await LineSDK.instance.setup('2011921761');
      debugPrint('--- LineSDK Prepared ---');
    } catch (e) {
      debugPrint('LineSDK setup error: $e');
    }
  }

  if (_supportsCameraInitialization) {
    availableCameras().then((cams) {
      cameras = cams;
      debugPrint('--- Cameras initialized: ${cameras.length} ---');
    }).catchError((e) {
      debugPrint('Camera error: $e');
    });
  } else {
    debugPrint('--- Camera initialization skipped on desktop platform ---');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('--- Building MyApp ---');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Slow On Move',
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(),
    );
  }
}
