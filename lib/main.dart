import 'package:StarSight/business_layer/app_audio_lifecycle_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/screen_time_gate.dart';
import 'package:StarSight/ui_layer/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'business_layer/audio_settings.dart';
import 'business_layer/audio_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppAudioLifecycleService.instance.init();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  OrientationService.setPortrait();

  await Future.wait([Firebase.initializeApp()]);

  await dotenv.load(fileName: ".env");

  await SfxHelper.instance.init();
  SfxHelper.instance.preload([Sfx.keyTap]);

  WidgetsFlutterBinding.ensureInitialized();
  await AudioSettings.instance.load();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ScreenTimeGate(child: child),
      home: SplashScreen(),
    );
  }
}
