import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'login_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('--- App Starting ---');

  // Facebook Web 初始化
  if (kIsWeb) {
    await FacebookAuth.i.webAndDesktopInitialize(
      appId: '1544257417341589',
      cookie: true,
      xfbml: true,
      version: 'v19.0',
    );
  }

  try {
    cameras = await availableCameras();
    debugPrint('--- Cameras initialized: ${cameras.length} ---');
  } catch (e) {
    debugPrint('Camera error: $e');
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
