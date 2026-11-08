import 'dart:async';
import 'package:StarSight/business_layer/global_star_counter.dart';
import 'package:StarSight/business_layer/forest_progress_service.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../business_layer/music_zones.dart';
import '../../games_ui_layer/alphabet_forest/forest_flow.dart';
import '../loading_screen.dart';
import '../starsight_setup_dialog.dart';
import 'forest_theme.dart';

class ForestLevelScreen extends StatefulWidget {
  const ForestLevelScreen({super.key});

  @override
  State<ForestLevelScreen> createState() => _ForestLevelScreenState();
}

class _ForestLevelScreenState extends State<ForestLevelScreen>
    with MusicZoneMixin {
  int _currentPage = 0;
  int _unlockedLevel = 5;
  bool _isLoadingProgress = true;
  StreamSubscription<int>? _progressSub;
  final DateTime _loadStart = DateTime.now();

  // --- honey counter / star animation ---
  final GlobalKey _jarKey = GlobalKey();
  final Map<int, GlobalKey> _tileKeys = {};
  Set<int> _playedLevels = {}; // what Firestore says the child has played
  Set<int> _shownLevels = {}; // levels whose star badge is already on screen
  int? _flyingLevel; // star is in the air toward this tile
  int? _justLanded; // plays the little pop on the badge that just landed
  bool _celebrating = false;

  // The minigames leave with pushReplacement(ForestLevelScreen()), which builds
  // a BRAND-NEW screen, so instance fields are lost. Remember what badges were
  // on screen last time (per child) so the new screen knows which stars are new.
  static Set<int> _carryShown = {};
  static String? _carryChild;
  bool _forceSetup = false;

  void _remember() {
    _carryShown = {..._shownLevels};
    _carryChild = ForestProgressService.instance.activeChildId;
  }

  void _showSetup() {
    final force = _forceSetup;
    _forceSetup = false;
    StarsightSetupTutorial.show(
      context,
      levelId: 'alphabet_forest',
      forceShow: force,
      onDone: () {},
    );
  }

  GlobalKey _keyFor(int level) =>
      _tileKeys.putIfAbsent(level, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _listenToProgress();
  }

  void _listenToProgress() {
    _progressSub = ForestProgressService.instance.streamUnlockedLevel().listen((
      level,
    ) async {
      if (!mounted) return;

      final wasLoading = _isLoadingProgress;

      if (_isLoadingProgress) {
        final elapsed = DateTime.now().difference(_loadStart);
        final remaining = const Duration(milliseconds: 1500) - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        if (!mounted) return;
      }

      // First load: fetch which levels were played so the counter and badges
      // are right on the very first frame (no flash of 0/25).
      Set<int>? played;
      if (wasLoading) {
        played = await ForestProgressService.instance.getPlayedLevels();
        if (!mounted) return;
      }

      setState(() {
        _unlockedLevel = level;
        _isLoadingProgress = false;
        if (played != null) {
          _playedLevels = played;
          final carried =
              _carryChild == ForestProgressService.instance.activeChildId
              ? _carryShown
              : <int>{};
          // Only trust the carried set if it still fits (no new cycle).
          _shownLevels = played.containsAll(carried) && carried.isNotEmpty
              ? {...carried}
              : {...played};
          _remember();
        }
      });

      // FIX: Move the setup dialog inside a check for fresh launch (wasLoading)
      // but ensure we wait for layout first.
      if (wasLoading) {
        _forceSetup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // New star(s) since this screen was last shown? Fly them first;
          // the setup dialog opens when the last one has landed.
          if (_playedLevels.difference(_shownLevels).isNotEmpty) {
            _celebrateNext();
          } else {
            _showSetup();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _openLevel(Widget screen) async {
    final route = MaterialPageRoute<void>(builder: (context) => screen);
    await Navigator.push(context, route);
    // push() completes the moment the level is popped, while it is still
    // sliding away. Wait for the transition to end so the star isn't launched
    // behind/over a half-gone page.
    await route.completed.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    if (!mounted) return;
    // If the level replaced itself with a NEW level screen, that one is on top
    // and handles the celebration. Don't fly a star under it.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    var played = await ForestProgressService.instance.getPlayedLevels();
    // The level's save can land AFTER we get back here. If we looked now and
    // found nothing new, we'd skip the star and open the setup dialog on top
    // of the screen. So give the save a moment to arrive before deciding.
    for (
      var i = 0;
      i < 6 && mounted && played.difference(_shownLevels).isEmpty;
      i++
    ) {
      await Future.delayed(const Duration(milliseconds: 300));
      played = await ForestProgressService.instance.getPlayedLevels();
    }
    if (!mounted) return;
    _playedLevels = played;

    // A new cycle started (data was cleared): just resync, no celebration.
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

  /// Flies a star from the honey jar to each newly played level's tile
  /// (one after another) and ticks the counter as each one lands.
  void _celebrateNext() {
    if (!mounted || _celebrating) return;
    final fresh = _playedLevels.difference(_shownLevels).toList()..sort();

    // FIX: If no animation is needed, we still want to ensure the dialog checks if it needs to pop up.
    if (fresh.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showSetup();
      });
      return;
    }

    _celebrating = true;
    final level = fresh.first;

    // make sure the tile's page is showing
    final lastPage = 3;
    final page = ((level - 1) ~/ 8).clamp(0, lastPage);
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
          _shownLevels = {
            ..._shownLevels,
            level,
          }; // counter ticks + badge appears
          _flyingLevel = null;
          _justLanded = level;
        });
        _celebrating = false;
        _remember();

        // Check if there are more stars to fly.
        final remainingFresh = _playedLevels.difference(_shownLevels).toList();
        if (remainingFresh.isEmpty) {
          // FIX: Once ALL stars finish flying, THEN show the setup dialog.
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

      // FIX: End position modified to target the corner of the tile
      // The badge is drawn at right/bottom: -size*0.08 (see _LevelTile), so
      // aim at its true center or the star "jumps" when it lands.
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

  List<Widget> _buildLevelRows(double tileSize) {
    final pages = [
      [1, 2, 3, 4, 5, 6, 7, 8],
      [9, 10, 11, 12, 13, 14, 15, 16],
      [17, 18, 19, 20, 21, 22, 23, 24],
      [25, 26, 27, 28, 29, 30],
    ];

    final levels = pages[_currentPage];

    Widget buildSlot(int index) {
      if (index >= levels.length) {
        return SizedBox(width: tileSize, height: tileSize);
      }

      return _LevelTile(
        level: levels[index],
        unlockedLevel: _unlockedLevel,
        onOpenLevel: _openLevel,
        size: tileSize,
        tileKey: _keyFor(levels[index]),
        hasStar: _shownLevels.contains(levels[index]),
        popStar: _justLanded == levels[index],
      );
    }

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [buildSlot(0), buildSlot(1), buildSlot(2), buildSlot(3)],
      ),

      const SizedBox(height: 16),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [buildSlot(4), buildSlot(5), buildSlot(6), buildSlot(7)],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProgress) {
      return Scaffold(body: LoadingScreen.alphabetForest());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_forest.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(top: 25, left: 20, child: ForestBackButton()),

          Positioned(
            top: 22,
            right: 20,
            child: GlobalStarCounter(
              count: _shownLevels.length.clamp(
                0,
                ForestProgressService.totalLevels,
              ),
              total: ForestProgressService.totalLevels,
              jarKey: _jarKey,
            ),
          ),

          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = MediaQuery.of(context).size.width;
                final screenH = MediaQuery.of(context).size.height;

                final cardWidth = (screenW * 0.75).clamp(320.0, 700.0);
                final cardHeight = (screenH * 0.80).clamp(220.0, 320.0);
                final tileSize = (cardWidth / 4 - 24).clamp(48.0, 90.0);
                final arrowSize = (tileSize * 0.85).clamp(40.0, 70.0);

                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ForestColorTheme.darkbrown,
                            width: 8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _buildLevelRows(tileSize),
                        ),
                      ),

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
                                color: ForestColorTheme.forestgreen,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: ForestColorTheme.darkgreen,
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
                                  fontFamily: ForestAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: ForestColorTheme.peach,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
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
                        left: -arrowSize * 0.5,
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
                              'assets/images/arrows/bttn_forest_arrow_left.png',
                              width: arrowSize,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: -arrowSize * 0.5,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            SfxHelper.instance.play(Sfx.keyTap);
                            if (_currentPage < 3) {
                              setState(() => _currentPage++);
                            }
                          },
                          child: Opacity(
                            opacity: _currentPage < 3 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_forest_arrow_right.png',
                              width: arrowSize,
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
  final Future<void> Function(Widget screen) onOpenLevel;
  final double size;
  final GlobalKey tileKey;
  final bool hasStar; // child has played this level
  final bool popStar; // badge just landed: play the pop-in

  const _LevelTile({
    required this.level,
    required this.unlockedLevel,
    required this.onOpenLevel,
    required this.size,
    required this.tileKey,
    this.hasStar = false,
    this.popStar = false,
  });

  Widget? _screenForLevel() => ForestFlow.screenForLevel(level);

  @override
  Widget build(BuildContext context) {
    final bool isLocked = level > unlockedLevel;

    if (isLocked) {
      return _LockedTile(size: size);
    }

    return GestureDetector(
      onTap: () {
        SfxHelper.instance.play(Sfx.keyTap);
        final screen = _screenForLevel();

        if (screen == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Coming Soon!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: ForestColorTheme.darkgreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }

        onOpenLevel(screen);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: tileKey,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: ForestColorTheme.forestgreen,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ForestColorTheme.darkgreen, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: ForestAppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: ForestColorTheme.darkgreen,
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
