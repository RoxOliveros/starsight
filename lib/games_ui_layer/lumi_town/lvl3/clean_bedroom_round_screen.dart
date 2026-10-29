import 'dart:async';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../business_layer/orientation_service.dart';
import '../../../../ui_layer/lumi_town/lumi_buttons.dart';
import '../../games_audio_helper.dart';
import '../../how_to_play_overlay.dart';
import '../../idle_hint_mixin.dart';
import '../lumi_game_ui_layer.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'clean_bedroom_data.dart';
import 'clean_bedroom_ending_screen.dart';

class BedroomRoundScreen extends StatefulWidget {
  final int roundIndex;
  final List<List<String>> rounds;
  final List<String> priorEmotions;
  final GameTapTracker tapTracker;
  final int level;

  const BedroomRoundScreen({
    super.key,
    required this.roundIndex,
    required this.rounds,
    required this.priorEmotions,
    required this.tapTracker,
    required this.level,
  });

  @override
  State<BedroomRoundScreen> createState() => _BedroomRoundScreenState();
}

class _BedroomRoundScreenState extends State<BedroomRoundScreen>
    with
        TickerProviderStateMixin,
        AiCameraMixin<BedroomRoundScreen>,
        AppAudioLifecycleMixin<BedroomRoundScreen>,
        IdleHintMixin {
  final AudioPlayer _player = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_player];

  static const String _roundDoneAudio = 'assets/audio/lumi_town/level3/vo_round_done.wav';
  static const String _wrongAudio = 'assets/audio/lumi_town/level3/vo_wrong.wav';

  static const String _bgImage = 'assets/images/backgrounds/bg_lumi_bed.png';

  static const List<Offset> _toyPositions = [
    Offset(0.83, 0.91), // airplane
    Offset(0.545, 0.65), // cap
    Offset(0.12, 0.51), // dinosaur
    Offset(0.40, 0.48), // doll
    Offset(0.50, 0.45), // jar
    Offset(0.60, 0.55), // key
    Offset(0.82, 0.42), // ball
    Offset(0.47, 0.91), // train
    Offset(0.32, 0.85), // umbrella
    Offset(0.70, 0.93), // xylophone
    Offset(0.92, 0.47), // yarn
    Offset(0.95, 0.85), // yoyo
  ];

  final Map<int, String> _filledSlots = {};
  final Set<String> _pickedUp = {};

  late List<AnimationController> _slotShakeCtrl;
  late List<Animation<double>> _slotShakeAnim;
  late List<AnimationController> _slotPopCtrl;
  late List<Animation<double>> _slotPopAnim;
  late List<String> _targetIds;
  late List<String> _visibleToyIds;

  bool _roundComplete = false;
  bool _hideLightingCard = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OrientationService.setLandscape();

    sessionId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    startAiCamera();

    onFaceDetectionChanged = (detected) {
      if (detected && mounted) setState(() => _hideLightingCard = false);
    };

    _targetIds = List.from(widget.rounds[widget.roundIndex]);

    final alreadyPlaced = widget.rounds
        .sublist(0, widget.roundIndex)
        .expand((r) => r)
        .toSet();
    _visibleToyIds = kAllToyIds
        .where((id) => !alreadyPlaced.contains(id))
        .toList();

    // Init slot animations
    _slotShakeCtrl = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _slotShakeAnim = _slotShakeCtrl
        .map(
          (ctrl) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 40),
            TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 20),
            TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 20),
          ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut)),
        )
        .toList();

    _slotPopCtrl = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );

    _slotPopAnim = _slotPopCtrl
        .map(
          (ctrl) => TweenSequence([
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 50),
            TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 50),
          ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut)),
        )
        .toList();
    startIdleTimer();
  }

  @override
  void dispose() {
    disposeAiCamera();
    disposeIdleTimer();
    _player.dispose();
    for (final c in _slotShakeCtrl) {
      c.dispose();
    }
    for (final c in _slotPopCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Drag handlers ─────────────────────────────────────────────────────────

  Future<void> _onToyPickup(String toyId) async {
    if (_player.state == PlayerState.playing) {
      await waitForAudio(_player);
    }
    final toy = toyById(toyId);
    await playVoiceRestartingOnFaceLoss(_player, toy.audioPath);
  }

  Future<void> _onDropOnSlot(int slotIndex, String droppedToyId) async {
    if (_filledSlots.containsKey(slotIndex)) return;

    final expectedToyId = _targetIds[slotIndex];

    if (droppedToyId == expectedToyId) {
      widget.tapTracker.recordCorrectTap();
      setState(() {
        _filledSlots[slotIndex] = droppedToyId;
        _pickedUp.add(droppedToyId);
      });

      GamesSfxPlayer.instance.play(GameSfx.shine);
      _slotPopCtrl[slotIndex].forward(from: 0);

      if (_filledSlots.length == 3 && !_roundComplete) {
        _roundComplete = true;
        cancelIdleTimer();
        await Future.delayed(const Duration(milliseconds: 300));
        await playVoiceRestartingOnFaceLoss(_player, _roundDoneAudio);
        await waitForAudio(_player);
        if (!mounted) return;
        _goToNextRound();
      }
    } else {
      widget.tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      _slotShakeCtrl[slotIndex].forward(from: 0);
      await playVoiceRestartingOnFaceLoss(_player, _wrongAudio);
    }
  }

  void _goToNextRound() {
    final emotionsSoFar = [...widget.priorEmotions, ...stopAiCamera()];

    final nextIndex = widget.roundIndex + 1;
    if (nextIndex >= kRoundTargets.length) {
      Navigator.of(context).pushReplacement(
        _fadeRoute(
          CleanBedroomEndingScreen(
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        _fadeRoute(
          BedroomRoundScreen(
            roundIndex: nextIndex,
            rounds: widget.rounds,
            priorEmotions: emotionsSoFar,
            tapTracker: widget.tapTracker,
            level: widget.level,
          ),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown: (_) {
          widget.tapTracker.recordGenericTap();
          if (!_roundComplete) {
            if (showHowToPlay) setState(() => showHowToPlay = false);
            cancelIdleTimer();
          }
        },
        onPointerUp: (_) {
          if (!_roundComplete) startIdleTimer();
        },
        onPointerCancel: (_) {
          if (!_roundComplete) startIdleTimer();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                ..._buildScene(screenW, screenH),

                Positioned(top: 25, left: 25, child: LumiXButton()),
                Positioned(
                  top: 25,
                  right: 25,
                  child: LumiLevelBadge(level: widget.level),
                ),


                if (hasCapturedFirstFrame &&
                    !isFaceDetected &&
                    !_hideLightingCard)
                  LightingPromptCard(
                    onClose: () {
                      setState(() => _hideLightingCard = true);
                      releaseFaceGate();
                    },
                  ),

                if (showHowToPlay && !_roundComplete)
                  Positioned.fill(
                    child: HowToPlayOverlay(
                      previewChild: Stack(
                        fit: StackFit.expand,
                        children: _buildScene(screenW, screenH),
                      ),
                      handAlignment: _toyAlignment(_targetIds[_demoSlot], screenW),
                      handEndAlignment: _slotAlignment(_demoSlot, screenW, screenH),
                      handOffset: const Offset(0.15, 0.4),
                      onDismiss: resetIdleTimer,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  int get _demoSlot {
    for (int i = 0; i < _targetIds.length; i++) {
      if (!_filledSlots.containsKey(i)) return i;
    }
    return 0;
  }

  Alignment _toyAlignment(String toyId, double screenW) {
    final sceneW = screenW * 0.82;
    final p = _toyPositions[kAllToyIds.indexOf(toyId)];
    return Alignment(p.dx * sceneW / screenW * 2 - 1, p.dy * 2 - 1);
  }

  Alignment _slotAlignment(int i, double screenW, double screenH) {
    final panelW = screenW * 0.18;
    final slotSize = panelW * 0.55;
    final innerH = screenH - 85 - 10;
    final gap = (innerH - 3 * slotSize) / 4;
    final cy = 85 + gap * (i + 1) + slotSize * i + slotSize / 2;
    final cx = screenW - panelW / 2;
    return Alignment(cx / screenW * 2 - 1, cy / screenH * 2 - 1);
  }

  List<Widget> _buildScene(double screenW, double screenH) {
    final panelW = screenW * 0.18;
    final sceneW = screenW - panelW;
    final toySize = screenW * 0.085;
    final slotSize = panelW * 0.55;

    return [
      Positioned(
        left: 0, top: 0, width: sceneW, height: screenH,
        child: Image.asset(_bgImage, fit: BoxFit.cover),
      ),
      Positioned(
        right: 0, top: 0, width: panelW, height: screenH,
        child: _RightPanel(
          roundToyIds: _targetIds,
          filledSlots: _filledSlots,
          slotSize: slotSize,
          shakeAnims: _slotShakeAnim,
          popAnims: _slotPopAnim,
          onDrop: _onDropOnSlot,
        ),
      ),
      ..._buildScatteredToys(sceneW, screenH, toySize),
      Positioned(
        top: 12, left: 0, right: 0,
        child: Center(
          child: _RoundDots(total: kRounds.length, current: widget.roundIndex),
        ),
      ),
    ];
  }

  List<Widget> _buildScatteredToys(
    double sceneW,
    double screenH,
    double toySize,
  ) {
    return List.generate(_visibleToyIds.length, (i) {
      final toyId = _visibleToyIds[i];
      if (_pickedUp.contains(toyId)) return const SizedBox.shrink();

      final posIndex = kAllToyIds.indexOf(toyId);
      final dx = _toyPositions[posIndex].dx * sceneW - toySize / 2;
      final dy = _toyPositions[posIndex].dy * screenH - toySize / 2;

      return Positioned(
        left: dx,
        top: dy,
        child: _DraggableToy(
          toy: toyById(toyId),
          size: toySize,
          onPickup: () => _onToyPickup(toyId)
        ),
      );
    });
  }
}

// ── Right panel with 3 silhouette slots ──────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final List<String> roundToyIds;
  final Map<int, String> filledSlots;
  final double slotSize;
  final List<Animation<double>> shakeAnims;
  final List<Animation<double>> popAnims;
  final Future<void> Function(int slotIndex, String toyId) onDrop;

  const _RightPanel({
    required this.roundToyIds,
    required this.filledSlots,
    required this.slotSize,
    required this.shakeAnims,
    required this.popAnims,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF376477),
      padding: EdgeInsets.fromLTRB(10, 85, 10, 10),
      child: DottedBorder(
        color: Colors.white.withValues(alpha: 0.8),
        strokeWidth: 2,
        dashPattern: const [20, 10],
        borderType: BorderType.RRect,
        radius: const Radius.circular(18),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFd9d9d9),
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: shakeAnims[i],
                builder: (_, child) => Transform.translate(
                  offset: Offset(shakeAnims[i].value, 0),
                  child: child,
                ),
                child: ScaleTransition(
                  scale: popAnims[i],
                  child: _SlotTarget(
                    slotIndex: i,
                    toyId: roundToyIds[i],
                    filledWith: filledSlots[i],
                    size: slotSize,
                    onDrop: onDrop,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Single slot drop target ───────────────────────────────────────────────────

class _SlotTarget extends StatelessWidget {
  final int slotIndex;
  final String toyId;
  final String? filledWith;
  final double size;
  final Future<void> Function(int, String) onDrop;

  const _SlotTarget({
    required this.slotIndex,
    required this.toyId,
    required this.filledWith,
    required this.size,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = filledWith != null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !isFilled,
      onAcceptWithDetails: (details) => onDrop(slotIndex, details.data),
      builder: (context, candidateData, _) {
        final isHovering = candidateData.isNotEmpty && !isFilled;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isFilled
                ? Color(0xFFd9d9d9).withValues(alpha: 0.25)
                : isHovering
                ? Color(0xFFd9d9d9).withValues(alpha: 0.2)
                : Color(0xFFd9d9d9).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.all(size * 0.1),
          child: isFilled
              ? _ColoredToyImage(toyId: toyId, size: size)
              : _SilhouetteToyImage(toyId: toyId, size: size),
        );
      },
    );
  }
}

// ── Silhouette image (greyscale + dark tint) ──────────────────────────────────

class _SilhouetteToyImage extends StatelessWidget {
  final String toyId;
  final double size;

  const _SilhouetteToyImage({required this.toyId, required this.size});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        60,
        0.2126,
        0.7152,
        0.0722,
        0,
        60,
        0.2126,
        0.7152,
        0.0722,
        0,
        60,
        0,
        0,
        0,
        0.7,
        0,
      ]),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.1),
          BlendMode.srcATop,
        ),
        child: Image.asset(
          'assets/images/objects/lumi/$toyId.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.help_outline, color: Colors.white54),
        ),
      ),
    );
  }
}

// ── Full color image shown when slot is filled ────────────────────────────────

class _ColoredToyImage extends StatelessWidget {
  final String toyId;
  final double size;

  const _ColoredToyImage({required this.toyId, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/objects/lumi/$toyId.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.check_circle, color: Colors.greenAccent),
    );
  }
}

// ── Draggable toy widget ──────────────────────────────────────────────────────

class _DraggableToy extends StatelessWidget {
  final ToyItem toy;
  final double size;
  final VoidCallback onPickup;

  const _DraggableToy({
    required this.toy,
    required this.size,
    required this.onPickup,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _ToyIcon(imagePath: toy.imagePath, size: size, opacity: 1.0);
    final ghost = _ToyIcon(imagePath: toy.imagePath, size: size, opacity: 0.3);
    final feedback = _ToyIcon(
      imagePath: toy.imagePath,
      size: size * 1.1,
      opacity: 0.95,
    );

    return Draggable<String>(
      data: toy.id,
      onDragStarted: onPickup,
      feedback: feedback,
      childWhenDragging: ghost,
      child: icon,
    );
  }
}

class _ToyIcon extends StatelessWidget {
  final String imagePath;
  final double size;
  final double opacity;

  const _ToyIcon({
    required this.imagePath,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.help_outline, color: Colors.white),
      ),
    );
  }
}

// ── Round progress dots ───────────────────────────────────────────────────────

class _RoundDots extends StatelessWidget {
  final int total;
  final int current;

  const _RoundDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? Colors.greenAccent.withValues(alpha: 0.9)
                : active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ── Fade route helper ─────────────────────────────────────────────────────────

Route<void> _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 600),
  );
}
