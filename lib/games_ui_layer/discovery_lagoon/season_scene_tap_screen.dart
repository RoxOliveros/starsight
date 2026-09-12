import 'dart:async';
import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/pickup_game.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../audio_helper.dart';
import '../goodjob_prompt.dart';
import 'package:audioplayers/audioplayers.dart';
import '../star_round_indicator.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';
import 'kiki_reaction.dart';
import 'lagoon_game_ui.dart';

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
    with TickerProviderStateMixin, LagoonIntroMixin, KikiReactionMixin {
  final AudioPlayer _introPlayer = AudioPlayer();
  final AudioPlayer _kikiPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  late final AudioHelper _audioHelper = AudioHelper(
    shouldResumeOnForeground: () => _screenPhase == LagoonScreenPhase.game,
  );

  @override
  AudioPlayer get introAudioPlayer => _introPlayer;

  @override
  AudioPlayer get kikiPlayer => _kikiPlayer;

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  static const String _bgImage = 'assets/images/backgrounds/bg_rainbow_lagoon.png';

  static const String _audioIntro = 'assets/audio/discovery_lagoon/season_tap_intro.wav';
  static const String _audioWrong = 'assets/audio/sound_effects/bubble_pop.wav';

  static const Map<String, String> _seasonNames = {
    'spring': 'Spring',
    'summer': 'Summer',
    'fall': 'Fall',
    'winter': 'Winter',
  };

  static const Map<String, String> _seasonAudioKeys = {
    'spring': 'spring',
    'summer': 'summer',
    'fall': 'autumn',
    'winter': 'winter',
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
  int _starsLit = 0;

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
    initLagoonIntro();

    _audioHelper.playBackgroundMusic();

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

    startLagoonIntro(
      introAudioAsset: _audioIntro,
      onGameStart: () {
        if (mounted) setState(() => _screenPhase = LagoonScreenPhase.game);
      },
    );
  }

  @override
  void dispose() {
    _audioHelper.stopBackgroundMusic();
    _audioHelper.dispose();

    disposeLagoonIntro();
    _introPlayer.dispose();
    _kikiPlayer.dispose();
    _sfxPlayer.dispose();
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  bool get _isLastRound => _currentRound == _rounds.length - 1;

  Future<void> _onChoiceTap(String seasonId) async {
    if (_showFeedback) return;

    final scene = _rounds[_currentRound];
    final correct = seasonId == scene.seasonId;

    setState(() {
      _selectedSeasonId = seasonId;
      _isCorrect = correct;
      _showFeedback = true;
    });

    if (correct) {
      _bounceCtrl.forward(from: 0);
      showKikiReaction(KikiState.correct);
      LagoonAudio.instance.play(_seasonAudioKeys[scene.seasonId]!);
    } else {
      _shakeCtrl.forward(from: 0);
      await _sfxPlayer.play(AssetSource(_audioWrong.replaceFirst('assets/', '')));
      Future.delayed(Duration(seconds: 1));
      showKikiReaction(KikiState.wrong);
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    if (correct) {
      if (_isLastRound) {
        setState(() => _starsLit = _rounds.length);
        await LagoonProgressService.instance.markLevelComplete(widget.level);
        setState(() => _showWinDialog = true);
      } else {
        setState(() {
          _currentRound++;
          _starsLit = _currentRound;
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
      _starsLit = 0;
      _selectedSeasonId = null;
      _isCorrect = false;
      _showFeedback = false;
      _showWinDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _bgImage,
              fit: BoxFit.cover,
            ),
          ),
           _screenPhase == LagoonScreenPhase.intro
                ? _buildIntroContent()
                : _buildGameContent(),
          if (_screenPhase == LagoonScreenPhase.game) buildKiki(context),
          // X Button and Level Badge
          Positioned(top: 25, left: 25, child: const LagoonXButton()),
          Positioned(top: 25, right: 25, child: LagoonLevelBadge(level: widget.level)),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  Widget _buildIntroContent() {
    return Stack(
      children: [
        Positioned.fill(top: 48, child: buildLagoonIntroCharacter()),
      ],
    );
  }

  Widget _buildGameContent() {
    final scene = _rounds[_currentRound];
    final choiceIds = _seasonNames.keys.toList();

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 80,
                  left: 50,
                  right: 50,
                  bottom: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: _buildSceneCard(scene),
                      ),
                    ),
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
            StarRoundIndicator(
              totalRounds: _rounds.length,
              litCount: _starsLit,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ],
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
        border: Border.all(color: Colors.white, width: 0.1),
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
                alignment: Alignment.topCenter,
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
            Container(
              color: Colors.white.withValues(alpha: 0.85),
              child: Center(
                child: Image.asset(
                  seasonImages[seasonId]!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: LagoonColorTheme.pastelorange,
                    child: const Center(
                      child: Text('🖼️', style: TextStyle(fontSize: 32)),
                    ),
                  ),
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

  // ── Win overlay ───────────────────────────────────────────────────────────

  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      
      characterSizeFactor: 0.9,
      onNext: () async {

        if (context.mounted) {
          // 2. Push directly to the next level's screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PickupGame(level: widget.level + 1)),
          );
        }
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
