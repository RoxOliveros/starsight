import 'package:StarSight/games_ui_layer/arctic_numberland/game_addition_package_delivery.dart';
import 'package:flutter/material.dart';
import '../../games_ui_layer/arctic_numberland/game_addition_rescue_bridge.dart';
import '../../games_ui_layer/arctic_numberland/game_addition_subtraction_signboard.dart';
import '../../games_ui_layer/arctic_numberland/game_arctic_festival.dart';
import '../../games_ui_layer/arctic_numberland/game_aurora_catcher.dart';
import '../../games_ui_layer/arctic_numberland/game_decorate_snowy_tree.dart';
import '../../games_ui_layer/arctic_numberland/game_build_snowman.dart';
import '../../games_ui_layer/arctic_numberland/game_iceberg_tip.dart';
import '../../games_ui_layer/arctic_numberland/game_igloo_peekaboo.dart';
import '../../games_ui_layer/arctic_numberland/game_345_counting.dart';
import '../../games_ui_layer/arctic_numberland/game_345_odd_one_out.dart';
import '../../games_ui_layer/arctic_numberland/game_number_sequence.dart';
import '../../games_ui_layer/arctic_numberland/game_counting_trees.dart';
import '../../games_ui_layer/arctic_numberland/game_building_igloo.dart';
import '../../games_ui_layer/arctic_numberland/game_match_snowglobe.dart';
import '../../games_ui_layer/arctic_numberland/game_recognition.dart';
import '../../games_ui_layer/arctic_numberland/game_12_counting.dart';
import '../../games_ui_layer/arctic_numberland/game_counttap.dart';
import '../../games_ui_layer/arctic_numberland/number_introduction_screen.dart';
import '../../games_ui_layer/arctic_numberland/game_memory_match.dart';
import '../../games_ui_layer/arctic_numberland/game_penguin_line_walk.dart';
import '../../games_ui_layer/arctic_numberland/game_sled_shape_sort.dart';
import '../../games_ui_layer/arctic_numberland/game_shooting_star.dart';
import '../../games_ui_layer/arctic_numberland/game_snowglobe_shake_count.dart';
import '../../games_ui_layer/arctic_numberland/game_snowman_shape_hunt.dart';
import '../../games_ui_layer/arctic_numberland/game_subtraction_compare_game.dart';
import '../../games_ui_layer/arctic_numberland/game_subtraction_melting_ice_game.dart';
import '../../games_ui_layer/arctic_numberland/number_tracing_level_screen.dart';

class ArcticFlow {
  static const List<List<int>> introGroups = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [9, 10],
  ];

  static const int tracingStart = 30;
  static const List<List<int>> tracingGroups = [
    [0, 1, 2],
    [3, 4],
    [5, 6],
    [7, 8],
    [9, 10],
  ];

  /// Single source of truth for level order
  static Widget? screenForLevel(int level) {
    if (level >= 1 && level <= introGroups.length) {
      return NumberIntroductionScreen.forSequence(
        introGroups[level - 1],
        level: level,
      );
    }

    final t = level - tracingStart;
    if (t >= 0 && t < tracingGroups.length) {
      return NumberTracingLevelScreen(numbers: tracingGroups[t], level: level);
    }

    switch (level) {
      case 5: return const Number1to5MatchSnowglobesScreen(level: 5);
      case 6: return const NumberMemoryMatchGame(level: 6);
      case 7: return const Number345OddOneOutScreen(level: 7);
      case 8: return const SledShapeSortGame(level: 8);
      case 9: return const SnowmanShapeHuntGame(level: 9);
      case 10: return const IcebergTipGame(level: 10);
      case 11: return const Number12CountingObjectsScreen(level: 11);
      case 12: return const Number012TapCountScreen(level: 12);
      case 13: return const Number345CountingObjectsScreen(level: 13);
      case 14: return const CountingTreesScreen(level: 14);
      case 15: return const ShootingStarCountingGame(level: 15);
      case 16: return const IglooPeekabooGame(level: 16);
      case 17: return const BuildIglooScreen(level: 17);
      case 18: return const BuildSnowmanGame(level: 18);
      case 19: return const SnowglobeShakeGame(level: 19);
      case 20: return const DecorateSnowyTreeGame(level: 20);
      case 21: return const AdditionRescueBridgeGame(level: 21);
      case 22: return const AdditionPackageDeliveryGame(level: 22);
      case 23: return const SubtractionMeltingIceGame(level: 23);
      case 24: return const SubtractionCompareGame(level: 24);
      case 25: return const SignboardMathGame(level: 25);
      case 26: return const Number012RecognitionScreen(level: 26);
      case 27: return const AuroraCatcherGame(level: 27);
      case 28: return const PenguinLineWalkGame(level: 28);
      case 29: return const Number012345SequenceScreen(level: 29);
      case 35: return const ArcticFestivalFinaleGame(level: 35);
      default: return null;
    }
  }

  static Widget? screenAfterLevel(int level) => screenForLevel(level + 1);
}