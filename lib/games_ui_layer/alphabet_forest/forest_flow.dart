import 'package:flutter/material.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_intro.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/alphabet_trace.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_acorn_basket.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_apple_tree.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_berry_bush_harvest.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_butterfly_flower.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_catterpillar_letter_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_finale.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_fishing.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_letter_fireflies.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_letter_match.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_letter_treehouse.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_mail_delivery.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_mushroom_hidenseek.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_paw_print.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_stick_letter_builder.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_train.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/forest_game_yak_zebra_race.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_level.dart';

class ForestFlow {
  static const List<List<String>> groups = [
    ['A', 'B', 'C'], ['D', 'E', 'F'], ['G', 'H', 'I'],
    ['J', 'K', 'L'], ['M', 'N', 'O'], ['P', 'Q', 'R'],
    ['S', 'T', 'U'], ['V', 'W', 'X'], ['Y', 'Z'],
  ];

  static const Map<int, List<String>> traceLevels = {
    25: ['A', 'B', 'C', 'D', 'E'],
    26: ['F', 'G', 'H', 'I', 'J'],
    27: ['K', 'L', 'M', 'N', 'O'],
    28: ['P', 'Q', 'R', 'S', 'T'],
    29: ['U', 'V', 'W', 'X', 'Y', 'Z'],
  };

  static int levelOf(List<String> letters) => groupIndex(letters) + 1;

  static Widget screenAfter(List<String> letters) =>
      screenAfterLevel(levelOf(letters));

  static int groupIndex(List<String> letters) =>
      groups.indexWhere((g) => g.contains(letters.first.toUpperCase()));

  static List<String> traceLetters(int level) =>
      traceLevels[level] ?? traceLevels[25]!;

  /// Single source of truth for level order
  static Widget? screenForLevel(int level) {
    if (level >= 1 && level <= groups.length) {
      return AlphabetIntroScreen(letters: groups[level - 1]);
    }
    if (traceLevels.containsKey(level)) {
      return AlphabetTraceScreen(level: level);
    }

    switch (level) {
      case 10: return const ForestMailDeliveryGame(level: 10);
      case 11: return const ButterflyFlowerGardenGame(level: 11);
      case 12: return const ButterflyLetterMatchGame(level: 12);
      case 13: return const CaterpillarLetterMatchGame(level: 13);
      case 14: return const LetterFirefliesGame(level: 14);
      case 15: return const AlphabetFishingGame(level: 15);
      case 16: return const FollowThePawPrintsGame(level: 16);
      case 17: return const LetterTreehouseGame(level: 17);
      case 18: return const AcornBasketGame(level: 18);
      case 19: return const MushroomHideAndSeekGame(level: 19);
      case 20: return const BerryBushHarvestGame(level: 20);
      case 21: return const AlphabetAppleTreeGame(level: 21);
      case 22: return const YakZebraRaceGame(level: 22);
      case 23: return const FallenStickLetterBuilderGame(level: 23);
      case 24: return const AlphabetTrainGame(level: 24);
      case 30: return const AlphabetForestFinaleGame(level: 30);
      default: return null;
    }
  }

  static Widget screenAfterLevel(int level) =>
      screenForLevel(level + 1) ?? const ForestLevelScreen();
}