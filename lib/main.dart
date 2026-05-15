import 'package:StarSight/games_ui_layer/discovery_lagoon/animal_habitant_match.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:StarSight/ui_layer/splash_screen.dart';
import 'business_layer/lottie_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    Firebase.initializeApp(),
    LottieCache.instance.preload(['assets/animations/starsight.json']),
  ]);

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimalHabitatMatchScreen(),
    );
  }
}
