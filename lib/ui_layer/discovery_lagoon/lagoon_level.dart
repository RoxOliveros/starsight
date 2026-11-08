import 'dart:async';
import 'package:StarSight/business_layer/global_star_counter.dart';
import 'package:StarSight/business_layer/lagoon_progress_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/animal_lifecycle_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/catching_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/clothes_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/cold_hot_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/feed_the_animal.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/habitant_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/listening_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/living_nonliving_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/lunchbox_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/perfume_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/pickup_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/rainbow_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/seed_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/soft_hard_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/tree_game.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/weather_game.dart';
import 'package:StarSight/ui_layer/discovery_lagoon/lagoon_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../business_layer/music_zones.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/discovery_lagoon/bodyparts_assembly.dart';
import '../../games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_scene_builder_screen.dart';
import '../../games_ui_layer/discovery_lagoon/weather_tap_sort_screen.dart';
import '../../ui_layer/app_dialog.dart';
import '../loading_screen.dart';
import '../starsight_setup_dialog.dart';
import 'lagoon_theme.dart';

class LagoonLevelScreen extends StatefulWidget {
  const LagoonLevelScreen({super.key});

  @override
  State<LagoonLevelScreen> createState() => _LagoonLevelScreenState();
}

class _LagoonLevelScreenState extends State<LagoonLevelScreen>
    with MusicZoneMixin {
  int _currentPage = 0;
  final int _maxPages = 2;

  int _unlockedLevel = 5;
  bool _isLoading = true;
  bool _firstLoadStarted = false;
  StreamSubscription<int>? _progressSub;
  final DateTime _loadStart = DateTime.now();

  static const Duration _minLoadingTime = Duration(milliseconds: 1500);

  // --- star counter / star animation ---
  final GlobalKey _jarKey = GlobalKey();
  final Map<int, GlobalKey> _tileKeys = {};
  Set<int> _playedLevels = {}; // what Firestore says the child has played
  Set<int> _shownLevels = {}; // levels whose star badge is already on screen
  int? _flyingLevel; // star is in the air toward this tile
  int? _justLanded; // plays the little pop on the badge that just landed
  bool _celebrating = false;

  // Level games may leave with pushReplacement(...), which can build a NEW
  // screen, so instance fields are lost. Remember which badges were on screen
  // last time (per child) so a new screen knows which stars are new.
  static Set<int> _carryShown = {};
  static String? _carryChild;
  bool _forceSetup = false;

  void _remember() {
    _carryShown = {..._shownLevels};
    _carryChild = LagoonProgressService.instance.activeChildId;
  }

  void _applyLoadedPlayed(Set<int> played) {
    _playedLevels = played;
    final carried = _carryChild == LagoonProgressService.instance.activeChildId
        ? _carryShown
        : <int>{};
    // Only trust the carried set if it still fits (no new playthrough).
    _shownLevels = carried.isNotEmpty && played.containsAll(carried)
        ? {...carried}
        : {...played};
    _remember();
  }

  void _afterFirstLoad() {
    _forceSetup = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // New star(s) since this screen was last shown? Fly them first; the
      // setup dialog opens when the last one has landed.
      if (_playedLevels.difference(_shownLevels).isNotEmpty) {
        _celebrateNext();
      } else {
        _showSetup();
      }
    });
  }

  void _showSetup() {
    final force = _forceSetup;
    _forceSetup = false;
    StarsightSetupTutorial.show(
      context,
      levelId: 'discovery_lagoon',
      forceShow: force,
      onDone: () {},
    );
  }

  GlobalKey _keyFor(int level) =>
      _tileKeys.putIfAbsent(level, () => GlobalKey());

  /// Resolves once this screen is the visible one again (a game can swap
  /// itself for the next game, so push() may complete while another game is
  /// still on top).
  Future<void> _waitUntilVisible() async {
    final route = ModalRoute.of(context);
    final anim = route?.secondaryAnimation;
    if (route == null || anim == null || route.isCurrent) return;
    if (anim.status == AnimationStatus.dismissed) return;

    final visible = Completer<void>();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.dismissed && !visible.isCompleted) {
        visible.complete();
      }
    }

    anim.addStatusListener(onStatus);
    await visible.future;
    anim.removeStatusListener(onStatus);
    // let the page finish sliding back before launching the star
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// After a level screen closes: wait until visible, give the save a moment to
  /// land, then fly a star for every newly played level.
  Future<void> _checkForNewStars() async {
    await _waitUntilVisible();
    if (!mounted) return;

    var played = await LagoonProgressService.instance.getPlayedLevels();
    for (
      var i = 0;
      i < 6 && mounted && played.difference(_shownLevels).isEmpty;
      i++
    ) {
      await Future.delayed(const Duration(milliseconds: 300));
      played = await LagoonProgressService.instance.getPlayedLevels();
    }
    if (!mounted) return;
    _playedLevels = played;

    // A new playthrough started (data was cleared): just resync, no star.
    if (!played.containsAll(_shownLevels)) {
      setState(() => _shownLevels = {...played});
      _remember();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSetup();
      });
      return;
    }
    _celebrateNext();
  }

  /// Flies a star from the jar to each newly played level's tile (one after
  /// another) and ticks the counter as each one lands.
  void _celebrateNext() {
    if (!mounted || _celebrating) return;
    final fresh = _playedLevels.difference(_shownLevels).toList()..sort();

    if (fresh.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSetup();
      });
      return;
    }

    _celebrating = true;
    final level = fresh.first;

    // make sure the tile's page is showing (8 tiles per page, 3 pages)
    final page = ((level - 1) ~/ 8).clamp(0, 2);
    setState(() {
      _currentPage = page;
      _flyingLevel = level;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final jarBox = _jarKey.currentContext?.findRenderObject() as RenderBox?;
      final tileBox =
          _keyFor(level).currentContext?.findRenderObject() as RenderBox?;

      void land() {
        if (!mounted) return;
        setState(() {
          _shownLevels = {..._shownLevels, level};
          _flyingLevel = null;
          _justLanded = level;
        });
        _celebrating = false;
        _remember();

        final remainingFresh = _playedLevels.difference(_shownLevels).toList();
        if (remainingFresh.isEmpty) {
          // Once ALL stars finish flying, THEN show the setup dialog.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showSetup();
          });
        } else {
          _celebrateNext();
        }
      }

      if (jarBox == null || tileBox == null) {
        land(); // can't animate (e.g. tile not laid out): just show the result
        return;
      }

      // launch from where the star pops out of the jar's lid
      final from = jarBox.localToGlobal(
        Offset(jarBox.size.width * 0.5, jarBox.size.height * 0.28),
      );
      final tileRect = tileBox.localToGlobal(Offset.zero) & tileBox.size;
      final badge = tileRect.width * 0.38;

      // The badge is drawn slightly outside the tile's corner (see
      // _LevelTile), so aim at its true center or the star jumps on landing.
      final to = Offset(
        tileRect.right + tileRect.width * 0.08 - badge * 0.5,
        tileRect.bottom + tileRect.height * 0.08 - badge * 0.5,
      );

      SfxHelper.instance.play(Sfx.keyTap);
      flyStar(
        context: context,
        from: from,
        to: to,
        endSize: badge,
        onLanded: land,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _listenToProgress();
  }

  void _listenToProgress() {
    _progressSub = LagoonProgressService.instance.streamUnlockedLevel().listen((
      level,
    ) async {
      if (!mounted) return;

      // Always keep the latest unlocked level, but only run the first-load
      // sequence once (the stream can emit again while we are still loading).
      _unlockedLevel = level;
      if (_isLoading && _firstLoadStarted) return;

      final wasLoading = _isLoading;
      Set<int>? played;

      if (wasLoading) {
        _firstLoadStarted = true;
        final elapsed = DateTime.now().difference(_loadStart);
        final remaining = _minLoadingTime - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        played = await LagoonProgressService.instance.getPlayedLevels();
        if (!mounted) return;
      }

      setState(() {
        _isLoading = false;
        if (played != null) _applyLoadedPlayed(played);
      });

      if (wasLoading) _afterFirstLoad();
    });
  }

  Future<void> _openLevel(Widget screen) async {
    final route = MaterialPageRoute<void>(builder: (context) => screen);
    await Navigator.push(context, route);
    // push() completes the moment the level is popped, while it is still
    // sliding away. Wait for the transition so the star isn't launched early.
    await route.completed.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    if (!mounted) return;
    await _checkForNewStars();
  }

  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Let the games' X button find its way back to this screen.
    _route = ModalRoute.of(context);
    LagoonNav.levelRoute = _route;
  }

  @override
  void dispose() {
    if (identical(LagoonNav.levelRoute, _route)) LagoonNav.levelRoute = null;
    _progressSub?.cancel();
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.discoveryLagoon());
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_lagoon.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 20, child: LagoonBackButton()),

          // Star counter (the jar is where the flying star launches from)
          Positioned(
            top: 22,
            right: 20,
            child: GlobalStarCounter(
              count: _shownLevels.length.clamp(
                0,
                LagoonProgressService.totalLevels,
              ),
              total: LagoonProgressService.totalLevels,
              jarKey: _jarKey,
            ),
          ),

          // 🌿 Content
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);

                Widget buildTile(int level) {
                  if (level > 20) {
                    return SizedBox(width: tileSize, height: tileSize);
                  } else if (level <= _unlockedLevel) {
                    return _LevelTile(
                      level: level,
                      size: tileSize,
                      onOpenLevel: _openLevel,
                      tileKey: _keyFor(level),
                      hasStar: _shownLevels.contains(level),
                      popStar: _justLanded == level,
                    );
                  } else {
                    return _LockedTile(size: tileSize);
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: LagoonColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _currentPage * 8 + i + 1;
                                return buildTile(level);
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _currentPage * 8 + i + 5;
                                return buildTile(level);
                              }),
                            ),
                          ],
                        ),
                      ),
                      // SELECT LEVEL badge on top border
                      Positioned(
                        top: -32,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: LagoonColorTheme.ferngreen,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: LagoonColorTheme.gunmetalgreen,
                                  width: 5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Text(
                                ' SELECT LEVEL ',
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: LagoonColorTheme.peach,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            // Left star
                            Positioned(
                              top: -4,
                              left: -35,
                              child: Transform.rotate(
                                angle: -0.2,
                                child: Image.asset(
                                  'assets/images/night_star.png',
                                  width: 70,
                                ),
                              ),
                            ),
                            // Right star
                            Positioned(
                              top: -4,
                              right: -35,
                              child: Transform.rotate(
                                angle: 0.2,
                                child: Image.asset(
                                  'assets/images/night_star.png',
                                  width: 70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        left: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            if (_currentPage > 0) {
                              setState(() => _currentPage--);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_lagoon_arrow_left.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            if (_currentPage < _maxPages) {
                              setState(() => _currentPage++);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage < _maxPages ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_lagoon_arrow_right.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// String? _lagoonCalibratedSessionId;
//
// Future<void> _ensureLagoonCalibrated(BuildContext context) async {
//   final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
//   if (_lagoonCalibratedSessionId == uid) return;
//   _lagoonCalibratedSessionId = uid;
//
//   await Navigator.push(
//     context,
//
//     PageRouteBuilder(
//       opaque: false,
//       pageBuilder: (context, animation, secondaryAnimation) =>
//           CalibrationScreen(
//             childSessionId: uid,
//             onCalibrationDone: () => Navigator.pop(context),
//           ),
//     ),
//   );
// }

class _LevelTile extends StatelessWidget {
  final int level;
  final double size;
  final Future<void> Function(Widget screen) onOpenLevel;
  final GlobalKey tileKey;
  final bool hasStar;
  final bool popStar;

  const _LevelTile({
    required this.level,
    required this.size,
    required this.onOpenLevel,
    required this.tileKey,
    this.hasStar = false,
    this.popStar = false,
  });

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return BodyPartsAssemblyScreen(level: 1);
      case 2:
        return TreeGameScreen(level: 2);
      case 3:
        return const RainbowGameScreen(level: 3);
      case 4:
        return const FeedTheAnimalGame(level: 4);
      case 5:
        return const HabitantGame(level: 5);
      case 6:
        return const SoftHardGameScreen(level: 6);
      case 7:
        return ColdHotGame(level: 7);
      case 8:
        return const LunchboxHealthyUnhealthyFoodsGameIntro(level: 8);
      case 9:
        return const CatchingDifferentTasteGameScreen(level: 9);
      case 10:
        return SeasonSceneTapScreen(level: 10);
      case 11:
        return const ClothesGame(level: 11);
      case 12:
        return WeatherTapSortScreen(level: 12);
      case 13:
        return const WeatherGame(level: 13);
      case 14:
        return WeatherSceneBuilderScreen(level: 14);
      case 15:
        return PickupSchoolGame(level: 15);
      case 16:
        return const ListeningAnimalGame(level: 16);
      case 17:
        return const PerfumeGame(level: 17);
      case 18:
        return const SeedGame(level: 18);
      case 19:
        return AnimalLifecycleGame(level: 19);
      case 20:
        return LivingNonLivingGame(level: 20);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        SfxHelper.instance.play(Sfx.keyTap);
        //await _ensureLagoonCalibrated(context);
        if (!context.mounted) return;
        final screen = _screenForLevel();
        if (screen == null) return;
        onOpenLevel(screen);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            key: tileKey,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: LagoonColorTheme.sagegreen,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: LagoonColorTheme.gunmetalgreen,
                width: 5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: LagoonColorTheme.gunmetalgreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (hasStar)
            Positioned(
              right: -size * 0.08,
              bottom: -size * 0.08,
              child: StarBadge(size: size * 0.38, animateIn: popStar),
            ),
        ],
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  final double size;

  const _LockedTile({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size - 1,
      height: size - 1,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(17),
        color: Colors.grey.shade400,
        strokeWidth: 5,
        dashPattern: const [6, 3],
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/icons/lock.png',
              width: size * 0.5,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
