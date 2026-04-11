import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:device_preview/device_preview.dart';
import 'login_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera error: $e');
  }

  runApp(
    DevicePreview(
      enabled: true, // 開啟
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context), // 必加
      builder: DevicePreview.appBuilder, // 必加

      debugShowCheckedModeBanner: false,
      title: 'Slow On Move',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
