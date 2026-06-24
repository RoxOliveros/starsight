import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/season_object_match_screen.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';

/// A scene (image) the child must match to the correct [seasonId].
class SeasonScene {
  final String imagePath;
  final String seasonId;

  SeasonScene({required this.imagePath, required this.seasonId});
}

class SeasonSceneTapScreen extends StatefulWidget {
  final int level;

  const SeasonSceneTapScreen({super.key, required this.level});

  @override
  State<SeasonSceneTapScreen> createState() => _SeasonSceneTapScreenState();
}

class _SeasonSceneTapScreenState extends State<SeasonSceneTapScreen>
    with TickerProviderStateMixin {
  // All four season names, keyed by id — used to build the choice buttons.
  static const Map<String, String> _seasonNames = {
    'spring': 'Spring',
    'summer': 'Summer',
    'fall': 'Fall',
    'winter': 'Winter',
  };

  static final List<SeasonScene> _allScenes = [
    SeasonScene(
      imagePath: 'assets/images/objects/lagoon/spring.png',
      seasonId: 'spring',
    ),
    SeasonScene(
      imagePath: 'assets/images/objects/lagoon/summer.png',
      seasonId: 'summer',
    ),
    SeasonScene(
      imagePath: 'assets/images/objects/lagoon/autumn.png',
      seasonId: 'fall',
    ),
    SeasonScene(
      imagePath: 'assets/images/objects/lagoon/winter.png',
      seasonId: 'winter',
    ),
  ];

  late List<SeasonScene> _rounds;
  int _currentRound = 0;

  String? _selectedSeasonId;
  bool _isCorrect = false;
  bool _showFeedback = false;
  bool _showWinDialog = false;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();

    _rounds = List<SeasonScene>.from(_allScenes)..shuffle();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  bool get _isLastRound => _currentRound == _rounds.length - 1;

  Future<void> _onChoiceTap(String seasonId) async {
    if (_showFeedback) return; // ignore taps while resolving

    final scene = _rounds[_currentRound];
    final correct = seasonId == scene.seasonId;

    setState(() {
      _selectedSeasonId = seasonId;
      _isCorrect = correct;
      _showFeedback = true;
    });

    if (correct) {
      _bounceCtrl.forward(from: 0);
    } else {
      _shakeCtrl.forward(from: 0);
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (correct) {
      if (_isLastRound) {
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _currentRound++;
          _selectedSeasonId = null;
          _isCorrect = false;
          _showFeedback = false;
        });
      }
    } else {
      // Let them try again on the same scene
      setState(() {
        _selectedSeasonId = null;
        _showFeedback = false;
      });
    }
  }

  void _restart() {
    setState(() {
      _rounds = List<SeasonScene>.from(_allScenes)..shuffle();
      _currentRound = 0;
      _selectedSeasonId = null;
      _isCorrect = false;
      _showFeedback = false;
      _showWinDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = _rounds[_currentRound];
    final choiceIds = _seasonNames.keys.toList();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/bg_game_lagoon.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            // --- LEFT: Scene Image ---
                            Expanded(
                              flex: 7,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: _buildSceneCard(scene),
                              ),
                            ),

                            // --- RIGHT: 2x2 Image Choices ---
                            Expanded(
                              flex: 3,
                              child: GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: choiceIds
                                    .map((id) => _buildChoiceButton(id, scene))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    _buildProgressDots(),
                    const SizedBox(height: 10),
                  ],
                ),
              ],
            ),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── Scene card ────────────────────────────────────────────────────────────

  Widget _buildSceneCard(SeasonScene scene) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                scene.imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: LagoonColorTheme.pastelorange,
                  child: const Center(
                    child: Text('🖼️', style: TextStyle(fontSize: 56)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Choice button ─────────────────────────────────────────────────────────

  Widget _buildChoiceButton(String seasonId, SeasonScene scene) {
    final isSelected = _selectedSeasonId == seasonId;
    final showAsCorrect = _showFeedback && isSelected && _isCorrect;
    final showAsWrong = _showFeedback && isSelected && !_isCorrect;

    // Map seasonId to its image path
    final Map<String, String> seasonImages = {
      'spring': 'assets/images/objects/lagoon/spring_icon.png',
      'summer': 'assets/images/objects/lagoon/summer_icon.png',
      'fall': 'assets/images/objects/lagoon/autumn_icon.png',
      'winter': 'assets/images/objects/lagoon/winter_icon.png',
    };

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Image.asset(
              seasonImages[seasonId]!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: LagoonColorTheme.pastelorange,
                child: const Center(
                  child: Text('🖼️', style: TextStyle(fontSize: 32)),
                ),
              ),
            ),
            // Feedback overlay
            if (showAsCorrect || showAsWrong)
              Container(
                color:
                    (showAsCorrect
                            ? LagoonColorTheme.sagegreen
                            : const Color(0xFFE05A5A))
                        .withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    showAsCorrect ? '✓' : '✗',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (showAsCorrect) {
      button = ScaleTransition(scale: _bounceAnim, child: button);
    } else if (showAsWrong) {
      button = AnimatedBuilder(
        animation: _shakeAnim,
        builder: (context, child) {
          final offset = sin(_shakeAnim.value * pi * 6) * 6;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: button,
      );
    }

    return GestureDetector(onTap: () => _onChoiceTap(seasonId), child: button);
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
          ],
        ),
      ),
    );
  }

  // ── Progress dots ─────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_rounds.length, (i) {
        final done = i < _currentRound;
        final current = i == _currentRound;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: current ? 28 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: done
                ? LagoonColorTheme.darkbrown
                : current
                ? LagoonColorTheme.ferngreen
                : LagoonColorTheme.darkbrown.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  // ── Win overlay ───────────────────────────────────────────────────────────

  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      closeButtonColor: LagoonColorTheme.darkbrown,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SeasonObjectMatchScreen(level: 15),
          ),
        );
      },
      onRestart: () {
        _restart();
      },
      onBack: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LagoonLevelScreen()),
          (route) => route.isFirst,
        );
      },
    );
  }
}
