import 'dart:async';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../business_layer/music_zones.dart';
import '../../business_layer/orientation_service.dart';
import 'package:StarSight/business_layer/global_star_counter.dart';
import '../../business_layer/puzzle_progress_service.dart';
import '../../games_ui_layer/puzzle_glade/game_connect_the_dots_screen.dart';
import '../../games_ui_layer/puzzle_glade/game_copy_pattern.dart';
import '../../games_ui_layer/puzzle_glade/game_find_the_pair_screen.dart';
import '../../games_ui_layer/puzzle_glade/game_hidden_object.dart';
import '../../games_ui_layer/puzzle_glade/game_maze_path.dart';
import '../../games_ui_layer/puzzle_glade/game_odd_one_out_screen.dart';
import '../../games_ui_layer/puzzle_glade/game_rotate_shape.dart';
import '../../games_ui_layer/puzzle_glade/game_same_or_different.dart';
import '../../games_ui_layer/puzzle_glade/game_shape_fit.dart';
import '../../games_ui_layer/puzzle_glade/game_spot_the_difference.dart';
import '../../games_ui_layer/puzzle_glade/game_star_color_sort.dart';
import '../../games_ui_layer/puzzle_glade/game_pattern_match.dart';
import '../../games_ui_layer/puzzle_glade/game_memory_match.dart';
import '../../games_ui_layer/puzzle_glade/game_shadow_match.dart';
import '../../games_ui_layer/puzzle_glade/game_puzzle_object.dart';
import '../../games_ui_layer/puzzle_glade/game_basket_sort.dart';
import '../../games_ui_layer/puzzle_glade/game_size_sort.dart';
import '../../games_ui_layer/puzzle_glade/game_what_goes_together_screen.dart';
import '../../games_ui_layer/puzzle_glade/game_whats_missing.dart';
import '../../games_ui_layer/puzzle_glade/game_which_belongs_here.dart';
import '../loading_screen.dart';
import 'puzzle_buttons.dart';
import 'puzzle_theme.dart';
import '../starsight_setup_dialog.dart';

class PuzzleLevelScreen extends StatefulWidget {
  const PuzzleLevelScreen({super.key});

  @override
  State<PuzzleLevelScreen> createState() => _PuzzleLevelScreenState();
}

class _PuzzleLevelScreenState extends State<PuzzleLevelScreen>
    with MusicZoneMixin {
  int _page = 0;
  int _unlockedLevel = 5;
  bool _isLoadingProgress = true;
  final DateTime _loadStart = DateTime.now();

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
    _carryChild = PuzzleProgressService.instance.activeChildId;
  }

  void _applyLoadedPlayed(Set<int> played) {
    _playedLevels = played;
    final carried = _carryChild == PuzzleProgressService.instance.activeChildId
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
      levelId: 'puzzle_glade',
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

    var played = await PuzzleProgressService.instance.getPlayedLevels();
    for (
      var i = 0;
      i < 6 && mounted && played.difference(_shownLevels).isEmpty;
      i++
    ) {
      await Future.delayed(const Duration(milliseconds: 300));
      played = await PuzzleProgressService.instance.getPlayedLevels();
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
      _page = page;
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
    _loadInitialProgress();
  }

  Future<void> _loadInitialProgress() async {
    final unlocked = await PuzzleProgressService.instance.getUnlockedLevel();
    final played = await PuzzleProgressService.instance.getPlayedLevels();

    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    setState(() {
      _unlockedLevel = unlocked;
      _isLoadingProgress = false;
      _applyLoadedPlayed(played);
    });

    _afterFirstLoad();
  }

  Future<void> _refreshProgress() async {
    final unlocked = await PuzzleProgressService.instance.getUnlockedLevel();
    if (!mounted) return;
    setState(() => _unlockedLevel = unlocked);
  }

  Future<void> _openLevel(Widget screen) async {
    // A game can hand back the NEXT screen to open (pop(context, nextScreen)),
    // so keep going until a game closes without one.
    Widget? current = screen;
    while (current != null) {
      final target = current;
      final route = MaterialPageRoute<dynamic>(builder: (context) => target);
      final result = await Navigator.push(context, route);
      // push() completes the moment the level is popped, while it is still
      // sliding away. Wait for the transition before going on.
      await route.completed.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (!mounted) return;
      current = result is Widget ? result : null;
    }

    await _refreshProgress();
    if (!mounted) return;
    await _checkForNewStars();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProgress) {
      return Scaffold(body: LoadingScreen.puzzleGlade());
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_puzzle.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 20, child: PuzzleBackButton()),

          // Star counter (the jar is where the flying star launches from)
          Positioned(
            top: 22,
            right: 20,
            child: GlobalStarCounter(
              count: _shownLevels.length.clamp(
                0,
                PuzzleProgressService.totalLevels,
              ),
              total: PuzzleProgressService.totalLevels,
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
                          color: PuzzleColorTheme.vandecane,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: PuzzleColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _page * 8 + i + 1;
                                return _LevelTile(
                                  level: level,
                                  unlockedLevel: _unlockedLevel,
                                  onOpenLevel: _openLevel,
                                  size: tileSize,
                                  tileKey: _keyFor(level),
                                  hasStar: _shownLevels.contains(level),
                                  popStar: _justLanded == level,
                                );
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(4, (i) {
                                final level = _page * 8 + i + 5;
                                return _LevelTile(
                                  level: level,
                                  unlockedLevel: _unlockedLevel,
                                  onOpenLevel: _openLevel,
                                  size: tileSize,
                                  tileKey: _keyFor(level),
                                  hasStar: _shownLevels.contains(level),
                                  popStar: _justLanded == level,
                                );
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
                                color: PuzzleColorTheme.darkdesaturatedblue,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color:
                                      PuzzleColorTheme.verydarkdesaturatedblue,
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
                                  fontFamily: PuzzleAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: PuzzleColorTheme.peach,
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
                      // Left arrow
                      Positioned(
                        left: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            if (_page > 0) {
                              setState(() => _page--);
                            }
                          },
                          child: Opacity(
                            opacity: _page > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_jar_arrow_left.png',
                              width: 70,
                            ),
                          ),
                        ),
                      ),
                      // Right arrow
                      Positioned(
                        right: -35,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            if (_page < 2) {
                              setState(() => _page++);
                            }
                          },
                          child: Opacity(
                            opacity: _page < 2 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_jar_arrow_right.png',
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

class _LevelTile extends StatelessWidget {
  final int level;
  final int unlockedLevel;
  final double size;
  final Future<void> Function(Widget screen) onOpenLevel;
  final GlobalKey tileKey;
  final bool hasStar;
  final bool popStar;

  const _LevelTile({
    required this.level,
    required this.unlockedLevel,
    required this.onOpenLevel,
    required this.size,
    required this.tileKey,
    this.hasStar = false,
    this.popStar = false,
  });

  Widget? _screenForLevel() {
    switch (level) {
      case 1:
        return const StarColorSortScreen(level: 1);
      case 2:
        return const FindThePairScreen(level: 2);
      case 3:
        return const ShadowMatchScreen(level: 3);
      case 4:
        return const PuzzleObjectScreen(level: 4);
      case 5:
        return const BasketSortScreen(level: 5);
      case 6:
        return const SizeSortScreen(level: 6);
      case 7:
        return const WhatsMissingScreen(level: 7);
      case 8:
        return const ConnectTheDotsScreen(level: 8);
      case 9:
        return const CopyPatternScreen(level: 9);
      case 10:
        return const SpotDifferenceScreen(level: 10);
      case 11:
        return const PatternMatchScreen(level: 11);
      case 12:
        return const MemoryMatchScreen(level: 12);
      case 13:
        return const ShapeFitScreen(level: 13);
      case 14:
        return const MazePathScreen(level: 14);
      case 15:
        return const HiddenObjectScreen(level: 15);
      case 16:
        return const RotateTheShapeScreen(level: 16);
      case 17:
        return const WhatGoesTogetherScreen(level: 17);
      case 18:
        return const OddOneOutScreen(level: 18);
      case 19:
        return const SameOrDifferentScreen(level: 19);
      case 20:
        return const WhichBelongsHereScreen(level: 20);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (level > 20) {
      return SizedBox(width: size, height: size);
    }
    final bool isLocked = level > unlockedLevel;
    if (isLocked) {
      return _LockedTile(size: size);
    }

    return GestureDetector(
      onTap: () {
        SfxHelper.instance.play(Sfx.keyTap);
        final screen = _screenForLevel();
        if (screen == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
          return;
        }
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
              color: PuzzleColorTheme.goldenyellow,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: PuzzleColorTheme.darkdesaturatedblue,
                width: 5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: PuzzleAppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: PuzzleColorTheme.darkdesaturatedblue,
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
