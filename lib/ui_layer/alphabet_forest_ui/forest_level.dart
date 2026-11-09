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

/// Lets the minigames jump straight back to the (single) Forest level screen,
/// closing everything above it (dialogs, minigame, intro...). This replaces
/// pushReplacement(ForestLevelScreen()), which stacked a SECOND level screen on
/// top of the first (so Back had to be pressed twice, and the star animation
/// ran on the screen hidden underneath).
class ForestNav {
  ForestNav._();
  static Route<dynamic>? levelRoute;

  /// Set by the level screen; called right after backToLevels so the star check
  /// does not depend on route animation events alone.
  static VoidCallback? onReturned;

  /// Used by the X button: return to the level screen if it is on the stack
  /// (popping any chained games/intros above it), otherwise just pop once.
  static void leaveGame(BuildContext context) {
    final route = levelRoute;
    if (route != null && route.isActive) {
      Navigator.of(context).popUntil((r) => identical(r, route));
      debugPrint('[ForestLevel] leaveGame: popped to level route');
      WidgetsBinding.instance.addPostFrameCallback((_) => onReturned?.call());
    } else {
      Navigator.pop(context);
    }
  }

  static void backToLevels(BuildContext context) {
    final route = levelRoute;
    if (route != null && route.isActive) {
      Navigator.of(context).popUntil((r) => identical(r, route));
      debugPrint('[ForestLevel] backToLevels: popped to level route');
      WidgetsBinding.instance.addPostFrameCallback((_) => onReturned?.call());
    } else {
      debugPrint(
        '[ForestLevel] backToLevels: level route NOT active, opening a fresh screen',
      );
      // Fallback (level screen not on the stack): open a fresh one.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ForestLevelScreen()),
      );
    }
  }
}

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
      // The progress doc changed while we are showing (e.g. the level's save
      // arrived late): look for new stars. No-op while a game covers us.
      if (!wasLoading) _refreshAndCelebrate(fromReturn: false);

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

  ModalRoute<dynamic>? _route;
  VoidCallback? _detachVisibility;
  bool _checking = false;
  bool _recheck = false;
  DateTime? _lastReturnCheck;

  void _log(String m) => debugPrint('[ForestLevel] $m');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _detachVisibility?.call();
      _route = route;
      // Let the minigames find their way back to this screen.
      ForestNav.levelRoute = route;
      ForestNav.onReturned = () {
        if (mounted) _onBecameVisible(why: 'backToLevels');
      };
      _watchVisibility(route);
    }
  }

  /// Fires whenever a screen that was on top of this one has finished leaving,
  /// i.e. this screen is visible again. This works however the player got back
  /// (X, Back, Good Job > Back, a chain of Next > Next ...), so we no longer
  /// depend on _openLevel's Future (which completes too early when a game is
  /// swapped for the next one with pushReplacement).
  void _watchVisibility(ModalRoute<dynamic>? route) {
    final anim = route?.secondaryAnimation;
    if (anim == null) return;
    void onStatus(AnimationStatus status) {
      _log('secondaryAnimation status: $status');
      if (status == AnimationStatus.dismissed) {
        _onBecameVisible(why: 'secondaryAnimation');
      }
    }

    anim.addStatusListener(onStatus);
    _detachVisibility = () => anim.removeStatusListener(onStatus);
  }

  bool get _isVisible {
    final route = _route;
    if (route == null || !route.isCurrent) return false;
    final anim = route.secondaryAnimation;
    return anim == null || anim.status == AnimationStatus.dismissed;
  }

  Future<void> _onBecameVisible({String why = ''}) async {
    final now = DateTime.now();
    final last = _lastReturnCheck;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      _log('_onBecameVisible($why): skipped (duplicate trigger)');
      return;
    }
    _lastReturnCheck = now;
    _log('_onBecameVisible($why)');
    // let the page finish sliding back before launching the star
    await Future.delayed(const Duration(milliseconds: 400));
    await _refreshAndCelebrate(fromReturn: true);
  }

  @override
  void dispose() {
    _detachVisibility?.call();
    if (identical(ForestNav.levelRoute, _route)) {
      ForestNav.levelRoute = null;
      ForestNav.onReturned = null;
    }
    _progressSub?.cancel();
    OrientationService.setLandscape();
    super.dispose();
  }

  /// Reads what Firestore says was played and flies a star for each new level.
  ///
  /// [fromReturn] is true when we just came back from a game; then we also give
  /// the save a moment to land and open the setup dialog if nothing is new.
  Future<void> _refreshAndCelebrate({required bool fromReturn}) async {
    _log(
      'refresh(fromReturn=$fromReturn) mounted=$mounted '
      'loading=$_isLoadingProgress celebrating=$_celebrating checking=$_checking',
    );
    if (!mounted || _isLoadingProgress) return;
    if (_celebrating || _checking) {
      // Don't drop a return check: run again once the current pass ends.
      if (fromReturn) _recheck = true;
      return;
    }
    _checking = true;
    try {
      if (fromReturn) {
        // Wait for the game's save transaction to actually commit.
        await ForestProgressService.instance.lastSave.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        if (!mounted) return;
      }

      // Let the route finish settling instead of bailing out.
      for (var i = 0; i < 10 && mounted && !_isVisible; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (!mounted || !_isVisible || _celebrating) {
        _log(
          'refresh: bailing, visible=$_isVisible '
          'isCurrent=${_route?.isCurrent} '
          'secAnim=${_route?.secondaryAnimation?.status}',
        );
        return;
      }

      final played = await ForestProgressService.instance.getPlayedLevels();
      _log('refresh: played=$played shown=$_shownLevels carry=$_carryShown');
      if (!mounted || _celebrating) return;

      // Another (newer) level screen may already have shown some of these.
      if (_carryChild == ForestProgressService.instance.activeChildId) {
        _shownLevels = {..._shownLevels, ..._carryShown.intersection(played)};
      }
      _playedLevels = played;

      // A new cycle started (data was cleared): just resync, no celebration.
      if (!played.containsAll(_shownLevels)) {
        setState(() => _shownLevels = {...played});
        _remember();
        if (fromReturn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showSetup();
          });
        }
        return;
      }

      if (played.difference(_shownLevels).isEmpty) {
        if (fromReturn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showSetup();
          });
        }
        return;
      }

      _log('refresh: celebrating new stars');
      _celebrateNext();
    } finally {
      _checking = false;
      if (_recheck && mounted) {
        _recheck = false;
        _refreshAndCelebrate(fromReturn: true);
      }
    }
  }

  Future<void> _openLevel(Widget screen) async {
    // Coming back is handled by the visibility listener above, however many
    // games were chained or however the player left.
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => screen),
    );
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

      // Safety net: if onLanded never fires, don't leave _celebrating stuck.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _celebrating && _flyingLevel == level) land();
      });
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
