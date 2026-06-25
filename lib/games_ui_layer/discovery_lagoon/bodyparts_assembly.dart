import 'package:audioplayers/audioplayers.dart';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import '../../business_layer/lagoon_progress_service.dart';
import '../../ui_layer/discovery_lagoon/lagoon_background.dart';
import '../../ui_layer/discovery_lagoon/lagoon_buttons.dart';
import '../goodjob_prompt.dart';
import 'animal_habitant_match.dart';
import 'audio_helper.dart';
import 'bodyparts_drag.dart';
import 'intro_phase.dart';

// --- GENERIC THEME ---
abstract class ColorTheme {
  static const Color background = Color(0xFFE8F4F8);
  static const Color textDark = Color(0xFF5E463E);
  static const Color primary = Color(0xFF75D5FF);
  static const Color success = Color(0xFF82C84B);
  static const Color accent = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class BodyPartItem {
  final String id;
  final String imagePath;

  BodyPartItem({required this.id, required this.imagePath});
}

class BodyPartsAssemblyScreen extends StatefulWidget {
  final int level;

  const BodyPartsAssemblyScreen({super.key, required this.level});

  @override
  State<BodyPartsAssemblyScreen> createState() =>
      _BodyPartsAssemblyScreenState();
}

class _BodyPartsAssemblyScreenState extends State<BodyPartsAssemblyScreen>
    with TickerProviderStateMixin, LagoonIntroMixin {
  // ── Required by LagoonIntroMixin ────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  @override
  AudioPlayer get introAudioPlayer => _player;

  // ── Screen phase ─────────────────────────────────────────────────────────
  LagoonScreenPhase _screenPhase = LagoonScreenPhase.intro;

  final Set<String> _matchedParts = {};
  late List<BodyPartItem> _availableParts;

  final List<BodyPartItem> _allParts = [
    BodyPartItem(
      id: 'head',
      imagePath: 'assets/images/objects/lagoon/head.png',
    ),
    BodyPartItem(
      id: 'shoulder',
      imagePath: 'assets/images/objects/lagoon/shoulder.png',
    ),
    BodyPartItem(
      id: 'knee',
      imagePath: 'assets/images/objects/lagoon/knee.png',
    ),
    BodyPartItem(
      id: 'feet',
      imagePath: 'assets/images/objects/lagoon/feet.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    initLagoonIntro();
    _resetGame();

    startLagoonIntro(
      introAudioAsset: 'assets/audio/discovery_lagoon/bodyparts_assembly_intro.wav',
      onGameStart: () {
        if (mounted) setState(() => _screenPhase = LagoonScreenPhase.game);
      },
    );
  }

  @override
  void dispose() {
    disposeLagoonIntro();
    _player.dispose();
    OrientationService.setLandscape();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _matchedParts.clear();
      _availableParts = List.from(_allParts)..shuffle();
    });
  }

  void _showSuccessDialog() {
    LagoonProgressService.instance.markLevelComplete(widget.level);
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => GoodJobOverlay(
        characterImage: 'assets/images/characters/cat_holding_fishbone.png',
        closeButtonColor: LagoonTheme.wasteland,
        onNext: () {
          Navigator.pop(context); // Close the overlay
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AnimalHabitatMatchScreen(level: 13),
            ),
          );
        },
        onRestart: () {
          Navigator.pop(context); // Close the overlay
          setState(() {
            _screenPhase = LagoonScreenPhase.game; // stay in game phase
            _resetGame();
          });
        },
        onBack: () {
          Navigator.pop(context); // Close the overlay
          Navigator.pop(context); // Exit the game back to the map
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.background,
      body: LagoonBackground(
        child: SafeArea(
          child: _screenPhase == LagoonScreenPhase.intro
              ? _buildIntroContent()
              : _buildGameContent(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTRO
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildIntroContent() {
    return Stack(
      children: [
        const Positioned(top: 8, left: 12, child: LagoonBackButton()),
        Positioned.fill(top: 48, child: buildLagoonIntroCharacter()),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // GAME (unchanged from your original)
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildGameContent() {
    return Column(
      children: [
        // --- HEADER ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: LagoonBackButton(),
              ),
            ],
          ),
        ),

        // --- MAIN PUZZLE AREA ---
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double h = constraints.maxHeight;
              final double w = constraints.maxWidth;
              final double cx = w / 2; // ← declare cx/cy FIRST
              final double cy = h / 2;
              final double boxSize = h * 0.25;

              final double boyHeight = h * 1;
              final double boyWidth = boyHeight * 0.6;
              final double boyLeft = cx - boyWidth / 2;
              final double boyTop = cy - boyHeight / 2;

              final Offset headTarget = Offset(
                boyLeft + boyWidth * 0.20,
                boyTop + boyHeight * 0.15,
              );
              final Offset shoulderTarget = Offset(
                boyLeft + boyWidth * 0.71,
                boyTop + boyHeight * 0.44,
              );
              final Offset kneeTarget = Offset(
                boyLeft + boyWidth * 0.68,
                boyTop + boyHeight * 0.80,
              );
              final Offset feetTarget = Offset(
                boyLeft + boyWidth * 0.29,
                boyTop + boyHeight * 0.92,
              );

              final Offset headBoxCenter = Offset(cx - h * 0.45, cy - h * 0.25);
              final Offset shoulderBoxCenter = Offset(
                cx + h * 0.45,
                cy - h * 0.20,
              );
              final Offset feetBoxCenter = Offset(cx - h * 0.45, cy + h * 0.25);
              final Offset kneeBoxCenter = Offset(cx + h * 0.45, cy + h * 0.25);

              return Stack(
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/objects/lagoon/boy.png',
                      height: boyHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: ConnectingLinesPainter(
                      headBox: headBoxCenter,
                      headTarget: headTarget,
                      shoulderBox: shoulderBoxCenter,
                      shoulderTarget: shoulderTarget,
                      feetBox: feetBoxCenter,
                      feetTarget: feetTarget,
                      kneeBox: kneeBoxCenter,
                      kneeTarget: kneeTarget,
                    ),
                  ),

                  Positioned(
                    left: headBoxCenter.dx - boxSize / 2,
                    top: headBoxCenter.dy - boxSize / 2,
                    child: _buildTargetBox('head', boxSize),
                  ),
                  Positioned(
                    left: shoulderBoxCenter.dx - boxSize / 2,
                    top: shoulderBoxCenter.dy - boxSize / 2,
                    child: _buildTargetBox('shoulder', boxSize),
                  ),
                  Positioned(
                    left: feetBoxCenter.dx - boxSize / 2,
                    top: feetBoxCenter.dy - boxSize / 2,
                    child: _buildTargetBox('feet', boxSize),
                  ),
                  Positioned(
                    left: kneeBoxCenter.dx - boxSize / 2,
                    top: kneeBoxCenter.dy - boxSize / 2,
                    child: _buildTargetBox('knee', boxSize),
                  ),
                ],
              );
            },
          ),
        ),

        // --- DRAGGABLE PARTS ROW ---
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _availableParts.map((part) {
              if (_matchedParts.contains(part.id)) {
                return const SizedBox(width: 100);
              }

              return Draggable<String>(
                data: part.id,
                feedback: _DraggableImage(
                  imagePath: part.imagePath,
                  isDragging: true,
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _DraggableImage(imagePath: part.imagePath),
                ),
                child: _DraggableImage(imagePath: part.imagePath),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetBox(String targetId, double size) {
    bool isMatched = _matchedParts.contains(targetId);
    String? matchedImagePath = isMatched
        ? _allParts.firstWhere((p) => p.id == targetId).imagePath
        : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data == targetId && !isMatched,
      onAcceptWithDetails: (details) {
        setState(() {
          _matchedParts.add(targetId);
        });
        if (_matchedParts.length == _allParts.length) {
          LagoonAudio.instance.playThenCallback(targetId, _showSuccessDialog);
        } else {
          LagoonAudio.instance.play(targetId);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.white
                : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isHovering ? ColorTheme.success : Colors.black87,
              width: isHovering ? 6 : 4,
            ),
            boxShadow: [
              if (isHovering)
                BoxShadow(
                  color: ColorTheme.success.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
            ],
          ),
          child: isMatched
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(matchedImagePath!, fit: BoxFit.contain),
                )
              : null,
        );
      },
    );
  }
}

class _DraggableImage extends StatelessWidget {
  final String imagePath;
  final bool isDragging;

  const _DraggableImage({required this.imagePath, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: isDragging ? 1.2 : 1.0,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isDragging)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// --- UPDATED CUSTOM PAINTER ---
class ConnectingLinesPainter extends CustomPainter {
  final Offset headBox, headTarget;
  final Offset shoulderBox, shoulderTarget;
  final Offset feetBox, feetTarget;
  final Offset kneeBox, kneeTarget;

  ConnectingLinesPainter({
    required this.headBox,
    required this.headTarget,
    required this.shoulderBox,
    required this.shoulderTarget,
    required this.feetBox,
    required this.feetTarget,
    required this.kneeBox,
    required this.kneeTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Helper function to draw a line with a dot at the target
    void drawConnection(Offset box, Offset target) {
      canvas.drawLine(box, target, linePaint);
      canvas.drawCircle(target, 6.0, dotPaint); // Draws the pointer dot!
    }

    drawConnection(headBox, headTarget);
    drawConnection(shoulderBox, shoulderTarget);
    drawConnection(feetBox, feetTarget);
    drawConnection(kneeBox, kneeTarget);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
