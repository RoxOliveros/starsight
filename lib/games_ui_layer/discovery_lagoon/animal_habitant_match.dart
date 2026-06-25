import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/discovery_lagoon/season_scene_tap_screen.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../../ui_layer/discovery_lagoon/lagoon_level.dart';
import '../../ui_layer/discovery_lagoon/lagoon_theme.dart';
import '../goodjob_prompt.dart';
import 'audio_helper.dart';
import 'intro_phase.dart';
import 'package:audioplayers/audioplayers.dart';

class Habitat {
  final String id;
  final String imagePath;
  final String name;

  Habitat({required this.id, required this.imagePath, required this.name});
}

class Animal {
  final String name;
  final String imagePath;
  final String targetHabitatId;
  final String audioKey;
  final String answerAudioKey;

  Animal({
    required this.name,
    required this.imagePath,
    required this.targetHabitatId,
    required this.audioKey,
    required this.answerAudioKey,
  });
}

class AnimalHabitatMatchScreen extends StatefulWidget {
  final int level;

  const AnimalHabitatMatchScreen({super.key, required this.level});

  @override
  State<AnimalHabitatMatchScreen> createState() =>
      _AnimalHabitatMatchScreenState();
}

class _AnimalHabitatMatchScreenState extends State<AnimalHabitatMatchScreen>
    with TickerProviderStateMixin, LagoonIntroMixin {
  final AudioPlayer _introPlayer = AudioPlayer();

  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  @override
  AudioPlayer get introAudioPlayer => _introPlayer;

  bool _isMatched = false;
  int _currentAnimalIndex = 0;
  late final AnimationController _floatingController;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  final Map<String, bool> _flash = {};

  bool _showWinDialog = false;

  late List<Animal> _animals;

  bool get _isLast => _currentAnimalIndex == _animals.length - 1;

  final List<Habitat> _habitats = [
    Habitat(
      id: 'town',
      imagePath: 'assets/images/backgrounds/bg_town.png',
      name: 'Town',
    ),
    Habitat(
      id: 'arctic',
      imagePath: 'assets/images/backgrounds/bg_arctic.png',
      name: 'Arctic',
    ),
    Habitat(
      id: 'forest',
      imagePath: 'assets/images/backgrounds/bg_forest.png',
      name: 'Forest',
    ),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    initLagoonIntro();

    _animals = [
      Animal(
        name: 'Penguin',
        imagePath: 'assets/images/characters/doma_the_penguin.png',
        targetHabitatId: 'arctic',
        audioKey: 'q_penguin',
        answerAudioKey: 'a_penguin',
      ),
      Animal(
        name: 'Dog',
        imagePath: 'assets/images/characters/dog.png',
        targetHabitatId: 'town',
        audioKey: 'q_aso',
        answerAudioKey: 'a_aso',
      ),
      Animal(
        name: 'Bear',
        imagePath: 'assets/images/characters/little_bear.png',
        targetHabitatId: 'forest',
        audioKey: 'q_bear',
        answerAudioKey: 'a_bear',
      ),
    ]..shuffle();

    for (final h in _habitats) {
      _flash[h.id] = false;
    }

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut));

    startLagoonIntro(
      introAudioAsset: 'assets/audio/discovery_lagoon/animal_habitat_intro.wav',
      onGameStart: () {
        if (mounted) {
          setState(() => _screenPhase = LagoonScreenPhase.game);
          Future.delayed(
            const Duration(milliseconds: 300),
            _playCurrentAnimalAudio,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    disposeLagoonIntro();
    _introPlayer.dispose();
    _floatingController.dispose();
    _bounceCtrl.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _playCurrentAnimalAudio() {
    LagoonAudio.instance.play(_animals[_currentAnimalIndex].audioKey);
  }

  Future<void> _onCorrectDrop() async {
    setState(() => _isMatched = true);
    _bounceCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final answerKey = _animals[_currentAnimalIndex].answerAudioKey;

    if (_isLast) {
      LagoonAudio.instance.playThenCallback(answerKey, () {
        if (!mounted) return;
        LagoonAudio.instance.playThenCallback('success', () {
          if (mounted) setState(() => _showWinDialog = true);
        });
      });
    } else {
      LagoonAudio.instance.playThenCallback(answerKey, () {
        if (!mounted) return;
        setState(() {
          _isMatched = false;
          _currentAnimalIndex++;
        });
        Future.delayed(
          const Duration(milliseconds: 300),
          _playCurrentAnimalAudio,
        );
      });
    }
  }

  Future<void> _onWrongDrop(String habitatId) async {
    setState(() => _flash[habitatId] = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _flash[habitatId] = false);
  }

  void _restart() {
    setState(() {
      _isMatched = false;
      _showWinDialog = false;
      _currentAnimalIndex = 0;
      _animals.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            child: _screenPhase == LagoonScreenPhase.intro
                ? _buildIntroContent()
                : _buildGameContent(),
          ),
          if (_showWinDialog) Positioned.fill(child: _buildGoodJobOverlay()),
        ],
      ),
    );
  }

  // ── NEW: intro phase ─────────────────────────────────────────────
  Widget _buildIntroContent() {
    return Stack(
      children: [
        const Positioned(top: 8, left: 12, child: LagoonBackButton()),
        Positioned.fill(top: 48, child: buildLagoonIntroCharacter()),
      ],
    );
  }

  Widget _buildGameContent() {
    final currentAnimal = _animals[_currentAnimalIndex];
    final double screenHeight = MediaQuery.of(context).size.height;
    final double animalSize = screenHeight * 0.25;

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(),
            // --- 3 HABITAT BACKGROUNDS (Drag Targets) ---
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: _habitats.map((habitat) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ScaleTransition(
                          scale:
                              (currentAnimal.targetHabitatId == habitat.id &&
                                  _isMatched)
                              ? _bounceAnim
                              : const AlwaysStoppedAnimation(1.0),
                          child: DragTarget<String>(
                            onWillAcceptWithDetails: (details) => true,
                            onAcceptWithDetails: (details) {
                              if (details.data == habitat.id) {
                                _onCorrectDrop();
                              } else {
                                _onWrongDrop(habitat.id);
                              }
                            },
                            builder: (context, candidateData, _) {
                              bool isHovering = candidateData.isNotEmpty;
                              bool isFlashing = _flash[habitat.id] ?? false;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isFlashing
                                        ? const Color(0xFFE05A5A)
                                        : isHovering
                                        ? LagoonColorTheme.ferngreen
                                        : Colors.white,
                                    width: isHovering || isFlashing ? 4 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isHovering
                                          ? LagoonColorTheme.ferngreen
                                                .withValues(alpha: 0.55)
                                          : Colors.black.withValues(
                                              alpha: 0.30,
                                            ),
                                      blurRadius: isHovering ? 18 : 12,
                                      spreadRadius: isHovering ? 2 : 0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // --- Photo area ---
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ColorFiltered(
                                              colorFilter: isHovering
                                                  ? const ColorFilter.mode(
                                                      Colors.transparent,
                                                      BlendMode.multiply,
                                                    )
                                                  : ColorFilter.mode(
                                                      Colors.black.withValues(
                                                        alpha: 0.10,
                                                      ),
                                                      BlendMode.darken,
                                                    ),
                                              child: Image.asset(
                                                habitat.imagePath,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            if (_isMatched &&
                                                currentAnimal.targetHabitatId ==
                                                    habitat.id)
                                              Center(
                                                child: Image.asset(
                                                  currentAnimal.imagePath,
                                                  height: animalSize * 0.8,
                                                ),
                                              ),
                                            if (isFlashing)
                                              Positioned(
                                                bottom: 6,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Text(
                                                    'Oops! ❌',
                                                    style: TextStyle(
                                                      fontFamily:
                                                          LagoonAppTextStyles
                                                              .fredoka,
                                                      fontSize: 14,
                                                      color: const Color(
                                                        0xFFE05A5A,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // --- Caption strip below photo ---
                                    SizedBox(
                                      height: 38,
                                      child: Center(
                                        child: Text(
                                          habitat.name,
                                          style: TextStyle(
                                            fontFamily:
                                                LagoonAppTextStyles.fredoka,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: LagoonColorTheme.darkbrown,
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
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // --- DRAGGABLE ANIMAL AREA ---
            Expanded(
              flex: 2,
              child: Center(
                child: _isMatched
                    ? const SizedBox.shrink()
                    : AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -10 * _floatingController.value),
                            child: child,
                          );
                        },
                        child: Draggable<String>(
                          data: currentAnimal.targetHabitatId,
                          feedback: _DraggableAnimal(
                            imagePath: currentAnimal.imagePath,
                            size: animalSize,
                            isDragging: true,
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.0,
                            child: _DraggableAnimal(
                              imagePath: currentAnimal.imagePath,
                              size: animalSize,
                            ),
                          ),
                          child: _DraggableAnimal(
                            imagePath: currentAnimal.imagePath,
                            size: animalSize,
                          ),
                        ),
                      ),
              ),
            ),
            _buildProgressDots(),
          ],
        ),
      ],
    );
  }

  // ── Header (pill-style title chip + back button, matches Lvl6) ──────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: LagoonBackButton()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: LagoonColorTheme.pastelorange,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: LagoonColorTheme.wasteland, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Animal Habitats',
                style: TextStyle(
                  fontFamily: LagoonAppTextStyles.fredoka,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: LagoonColorTheme.wasteland,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Progress dots ───────────────────────

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_animals.length, (i) {
        final done = i < _currentAnimalIndex;
        final current = i == _currentAnimalIndex;
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

  // ── Win overlay (replaces the plain AlertDialog) ─────────────────────────
  Widget _buildGoodJobOverlay() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    return GoodJobOverlay(
      characterImage: 'assets/images/characters/cat_holding_fishbone.png',
      closeButtonColor: LagoonColorTheme.darkbrown,
      onNext: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SeasonSceneTapScreen(level: 14),
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

// Helper widget for the animal image
class _DraggableAnimal extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isDragging;

  const _DraggableAnimal({
    required this.imagePath,
    required this.size,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          height: size,
          decoration: BoxDecoration(
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
