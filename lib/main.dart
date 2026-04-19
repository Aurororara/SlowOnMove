import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'main_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- App Starting ---');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      // App 一啟動就進入登入畫面
      home: const MainScreen(),
    );
  }
}