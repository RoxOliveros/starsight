import 'dart:async';
import 'package:StarSight/business_layer/arctic_progress_service.dart';
import 'package:StarSight/business_layer/global_star_counter.dart'; // <-- ADDED IMPORT
import 'package:StarSight/games_ui_layer/arctic_numberland/game_addition_package_delivery.dart';
import 'package:StarSight/ui_layer/arctic_numberland/arctic_buttons.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../business_layer/audio_helper.dart';
import '../../business_layer/music_zones.dart';
import '../../business_layer/orientation_service.dart';
import '../../games_ui_layer/arctic_numberland/arctic_flow.dart';
import '../loading_screen.dart';
import 'arctic_theme.dart';
import '../starsight_setup_dialog.dart';

class ArcticLevelScreen extends StatefulWidget {
  const ArcticLevelScreen({super.key});

  @override
  State<ArcticLevelScreen> createState() => _ArcticLevelScreenState();
}

class _ArcticLevelScreenState extends State<ArcticLevelScreen>
    with MusicZoneMixin {
  int _page = 0;
  int _unlockedLevel = 5;
  bool _isLoading = true;
  final DateTime _loadStart = DateTime.now();

  // --- honey counter / star animation ---
  final GlobalKey _jarKey = GlobalKey();
  final Map<int, GlobalKey> _tileKeys = {};
  Set<int> _playedLevels = {}; // what Firestore says the child has played
  Set<int> _shownLevels = {}; // levels whose star badge is already on screen
  int? _flyingLevel; // star is in the air toward this tile
  int? _justLanded; // plays the little pop on the badge that just landed
  bool _celebrating = false;

  // Level games leave with pushReplacement(ArcticLevelScreen()), which builds a
  // BRAND-NEW screen, so instance fields are lost. Remember which badges were
  // on screen last time (per child) so a new screen knows which stars are new.
  static Set<int> _carryShown = {};
  static String? _carryChild;
  bool _forceSetup = false;

  void _remember() {
    _carryShown = {..._shownLevels};
    _carryChild = ArcticProgressService.instance.activeChildId;
  }

  void _showSetup() {
    final force = _forceSetup;
    _forceSetup = false;
    StarsightSetupTutorial.show(
      context,
      levelId: 'arctic_numberland',
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
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final wasLoading = _isLoading;

    final unlocked = await ArcticProgressService.instance.getUnlockedLevel();

    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = const Duration(milliseconds: 1500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    Set<int>? played;
    if (wasLoading) {
      played = await ArcticProgressService.instance.getPlayedLevels();
    }

    if (!mounted) return;
    setState(() {
      _unlockedLevel = unlocked;
      _isLoading = false;
      if (played != null) {
        _playedLevels = played;
        final carried =
            _carryChild == ArcticProgressService.instance.activeChildId
            ? _carryShown
            : <int>{};
        // Only trust the carried set if it still fits (no new playthrough).
        _shownLevels = carried.isNotEmpty && played.containsAll(carried)
            ? {...carried}
            : {...played};
        _remember();
      }
    });

    if (wasLoading) {
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
  }

  /// Resolves once this screen is the visible one again.
  ///
  /// A game can swap itself for the NEXT game (the Next button uses
  /// pushReplacement), which completes push() while another game is still on
  /// top. The player only gets back here later, when that game pops, so wait
  /// for the route above us to leave before looking for new stars.
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
    // The game may have been swapped for the next game; wait until we are
    // actually visible again before looking for new stars.
    await _waitUntilVisible();
    if (!mounted) return;

    var played = await ArcticProgressService.instance.getPlayedLevels();
    // The level's save can land AFTER we get back here; give it a moment.
    for (
      var i = 0;
      i < 6 && mounted && played.difference(_shownLevels).isEmpty;
      i++
    ) {
      await Future.delayed(const Duration(milliseconds: 300));
      played = await ArcticProgressService.instance.getPlayedLevels();
    }
    if (!mounted) return;
    _playedLevels = played;

    // Update unlocked level too in case they beat a new level
    final unlocked = await ArcticProgressService.instance.getUnlockedLevel();
    if (mounted) setState(() => _unlockedLevel = unlocked);

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

    final lastPage = 4;
    final page = ((level - 1) ~/ 8).clamp(0, lastPage);
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showSetup();
          });
        } else {
          _celebrateNext();
        }
      }

      if (jarBox == null || tileBox == null) {
        land();
        return;
      }

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
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingScreen.arctic());
    }

    return Scaffold(
      body: Stack(
        children: [
          // 🌳 Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_arctic.png',
              fit: BoxFit.cover,
            ),
          ),

          //back button
          Positioned(top: 25, left: 20, child: ArcticBackButton()),

          // THE NEW GLOBAL STAR COUNTER
          Positioned(
            top: 22,
            right: 20,
            child: GlobalStarCounter(
              count: _shownLevels.length.clamp(
                0,
                ArcticProgressService.totalLevels,
              ),
              total: ArcticProgressService.totalLevels,
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
                      SizedBox(height: 20),
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ArcticColorTheme.slateblue,
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
                                color: ArcticColorTheme.lightblue,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: ArcticColorTheme.slateblue,
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
                              child: Text(
                                ' SELECT LEVEL ',
                                style: TextStyle(
                                  fontFamily: ArcticAppTextStyles.fredoka,
                                  fontSize: 25,
                                  color: ArcticColorTheme.lightgrayishcyan,
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
                            if (_page > 0) setState(() => _page--);
                          },
                          child: Opacity(
                            opacity: _page > 0 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_arctic_arrow_left.png',
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
                            if (_page < 4) setState(() => _page++);
                          },
                          child: Opacity(
                            opacity: _page < 4 ? 1.0 : 0.3,
                            child: Image.asset(
                              'assets/images/arrows/bttn_arctic_arrow_right.png',
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

  Widget? _screenForLevel() => ArcticFlow.screenForLevel(level);

  @override
  Widget build(BuildContext context) {
    if (level > 35) return SizedBox(width: size, height: size);

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
        alignment: Alignment.bottomCenter, // Fallback alignment
        children: [
          Container(
            key: tileKey,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: ArcticColorTheme.pictonblue,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: ArcticColorTheme.slateblue, width: 5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: TextStyle(
                fontFamily: ArcticAppTextStyles.fredoka,
                fontSize: size * 0.5,
                color: ArcticColorTheme.cadetblue,
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
            ),
          ),
        ),
      ),
    );
  }
}
