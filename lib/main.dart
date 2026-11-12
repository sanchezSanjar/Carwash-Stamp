import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'models/stamp_config.dart';
import 'screens/camera_screen.dart';
import 'services/logo_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  List<CameraDescription> cameras = const [];
  try {
    cameras = await availableCameras();
  } on CameraException catch (_) {
    cameras = const [];
  }

  final config = await StampConfig.load();
  final logoStore = LogoStore();
  await logoStore.load(config.logoPath);

  runApp(StampCameraApp(
    cameras: cameras,
    config: config,
    logoStore: logoStore,
  ));
}

class StampCameraApp extends StatelessWidget {
  const StampCameraApp({
    super.key,
    required this.cameras,
    required this.config,
    required this.logoStore,
  });

  final List<CameraDescription> cameras;
  final StampConfig config;
  final LogoStore logoStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carwash Stamp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7BD6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CameraScreen(
        cameras: cameras,
        initialConfig: config,
        logoStore: logoStore,
      ),
    );
  }
}
