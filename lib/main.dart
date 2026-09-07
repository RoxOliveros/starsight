import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'games_ui_layer/alphabet_forest/alphabet_minigame_fall.dart';
import 'games_ui_layer/alphabet_forest/alphabet_minigame_find.dart';
import 'games_ui_layer/alphabet_forest/alphabet_minigame_hunt.dart';
import 'games_ui_layer/alphabet_forest/alphabet_minigame_pop.dart';
import 'games_ui_layer/alphabet_forest/alphabet_minigame_puzzle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  OrientationService.setPortrait();

  await Future.wait([Firebase.initializeApp()]);

  await dotenv.load(fileName: ".env");
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: AlphabetPuzzleScreen(letter: 'd'));
  }
}
