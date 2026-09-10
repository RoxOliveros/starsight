import 'dart:math';
import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:StarSight/games_ui_layer/alphabet_forest/tofi_reaction.dart';
import 'package:StarSight/games_ui_layer/lighting_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/forest_progress_service.dart';
import '../../ui_layer/alphabet_forest_ui/forest_buttons.dart';
import '../../ui_layer/alphabet_forest_ui/forest_theme.dart';
import '../../ui_layer/game_loading_mixin.dart';
import '../../ui_layer/loading_screen.dart';
import '../goodjob_prompt.dart';
import 'alphabet_game_ui.dart';
import 'alphabet_intro.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'package:StarSight/games_ui_layer/ai_camera_mixin.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'forest_audio_helper.dart';

class ForestMailDeliveryGame extends StatefulWidget {
  final int level;

  const ForestMailDeliveryGame({super.key, required this.level});

  @override
  State<ForestMailDeliveryGame> createState() =>
      _ForestMailDeliveryGameState();
}

class _ForestMailDeliveryGameState extends State<ForestMailDeliveryGame>
    with TickerProviderStateMixin, GameLoadingMixin, ForestAudioMixin, TofiReactionMixin, AiCameraMixin {
  @override
  AudioPlayer get tofiPlayer => _player;

  final AudioPlayer _player = AudioPlayer();

  final GameTapTracker _tapTracker = GameTapTracker();

  static const List<String> _letters = ['A', 'B', 'C'];
  static const int _totalRounds = 5;

  String _displayLetter = 'A';
  String? _previousTarget;

  int _currentRound = 0; // 0-indexed, 0..4
  bool _canDrag = true;
  bool _parcelDelivered = false;

  // Visual feedback state for mailboxes.
  String? _bouncingMailbox;
  String? _shakingMailbox;

  bool _introPlaying = true;
  late AnimationController _tofiFloatCtrl;
  late AnimationController _mailboxBounceController;
  late AnimationController _mailboxShakeController;
  late AnimationController _parcelDragScaleController;

  // ── Asset paths ──────────────────────────────────────────────────────────
  static const String _dogImage = 'assets/images/characters/dog.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_forest_3houses.png';
  static const String _envelopImage = 'assets/images/objects/forest/envelope.png';
  static const String _mailboxImage = 'assets/images/objects/forest/mailbox.png';

  static const String _audioBase = ForestAudioAssets.base;
  static const String _audioIntro = '$_audioBase/mail_intro.wav';
  static const String _audioInstruction = '$_audioBase/mail_instruction.wav';
  static const String _audioWin = '$_audioBase/mail_win.wav';

  @override
  void initState() {
    OrientationService.setLandscape();
    super.initState();

    startAiCamera();
    _tapTracker.startSession();

    Future.microtask(() => playBackgroundMusic());

    _tofiFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _mailboxBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _mailboxShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _parcelDragScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    finishLoading(() {
      if (isFaceDetected) {
        onFirstFaceDetected?.call();
        onFirstFaceDetected = null;
      }
      _startIntroFlow();
    });

    _loadRound();
  }

  @override
  void dispose() {
    disposeAiCamera();
    stopBackgroundMusic();
    _tofiFloatCtrl.dispose();
    _mailboxBounceController.dispose();
    _mailboxShakeController.dispose();
    _parcelDragScaleController.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── INTRO ────────────────────────────────────────────────────────────

  Future<void> _startIntroFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    await playVoice(_audioIntro);

    if (!mounted) return;

    setState(() {
      _introPlaying = false;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await playVoice(_audioInstruction,);
  }


  // ── ROUND SETUP ──────────────────────────────────────────────────────

  void _loadRound() {
    final rand = Random();

    // Randomize target letter, avoiding an immediate repeat when possible.
    String next;
    do {
      next = _letters[rand.nextInt(_letters.length)];
    } while (_previousTarget != null &&
        next == _previousTarget &&
        _letters.length > 1);
    _previousTarget = next;

    final bool useLowercase;
    switch (_currentRound) {
      case 0:
        useLowercase = false; // Round 1: uppercase only
        break;
      case 1:
        useLowercase = true; // Round 2: lowercase only
        break;
      default:
        useLowercase = rand.nextBool(); // Rounds 3-5: random case
    }

    setState(() {
      _displayLetter = useLowercase ? next.toLowerCase() : next;
      _canDrag = true;
      _bouncingMailbox = null;
      _shakingMailbox = null;
      _parcelDelivered = false;
    });
  }

  // ── DROP HANDLING ────────────────────────────────────────────────────

  void _handleDrop(String mailboxLetter, String parcelLetter) {
    if (!_canDrag) return;

    if (parcelLetter.toUpperCase() == mailboxLetter) {
      _handleCorrect(mailboxLetter);
    } else {
      _handleWrong(mailboxLetter);
    }
  }

  void _handleCorrect(String mailboxLetter) {
    _tapTracker.recordCorrectTap();

    setState(() {
      _canDrag = false;
      _parcelDelivered = true;
      _bouncingMailbox = mailboxLetter;
    });

    _mailboxBounceController.forward(from: 0);
    showTofiReaction(TofiState.correct);

    Future.delayed(const Duration(milliseconds: 750), () async {
      if (!mounted) return;

      _currentRound++;

      if (_currentRound >= _totalRounds) {
        await _completeGame();
      } else {
        _loadRound();
      }
    });
  }

  void _handleWrong(String mailboxLetter) {
    _tapTracker.recordMistake();

    setState(() {
      _shakingMailbox = mailboxLetter;
    });

    showTofiReaction(TofiState.wrong);

    _mailboxShakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _shakingMailbox = null);
    });

    // Same target letter stays active; parcel returns to its spot
    // automatically since it was never accepted/removed from the tree.
  }

  // ── COMPLETION ───────────────────────────────────────────────────────

  Future<void> _completeGame() async {
    await ForestProgressService.instance.markLevelComplete(widget.level);

    if (!mounted) return;

    await playVoice(_audioWin);

    if (!mounted) return;

    await _saveDataAndShowGoodJob();
  }

  Future<void> _saveDataAndShowGoodJob() async {
    List<String> finalEmotions = stopAiCamera();

    try {
      String parentUid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('category_progress')
          .doc('alphabet_forest')
          .collection('games_played')
          .doc('forest_mail_delivery')
          .set({
        'activityName': 'Forest Mail Delivery',
        'emotions': finalEmotions,
        'totalTaps': _tapTracker.totalTaps,
        'mistakes': _tapTracker.mistakeCount,
        'timePlayedSeconds': _tapTracker.formattedDuration,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Database Error saving Forest Mail Delivery metrics: $e");
    }

    if (!mounted) return;
    _showGoodJob();
  }

  void _showGoodJob() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) => Material(
        type: MaterialType.transparency,
        child: GoodJobOverlay(
          characterImage: _dogImage,
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlphabetIntroScreen(letter: 'D'),
              ),
            );
          },
          onRestart: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    ForestMailDeliveryGame(level: widget.level),
              ),
            );
          },
          onBack: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildWithLoading(
        loadingScreen: LoadingScreen.alphabetForest(),
        gameBuilder: () => Stack(
          children: [
            if (_introPlaying) _buildIntroLayer() else _buildGameContent(),

            if (!_introPlaying) buildTofi(context),

            if (hasCapturedFirstFrame && !isFaceDetected)
              LightingPromptCard(
                onClose: () {
                  setState(() {
                    isFaceDetected = true;
                  });
                  onFirstFaceDetected?.call();
                  onFirstFaceDetected = null;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroLayer() {
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _bgImage,
            fit: BoxFit.cover,
          ),
        ),

        const Positioned(top: 25, left: 25, child: ForestXButton()),

        Positioned(
          top: 25,
          right: 20,
          child: ForestLevelBadge(level: widget.level),
        ),

        Center(
          child: AnimatedBuilder(
            animation: _tofiFloatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(
                0,
                Tween<double>(begin: -6, end: 6).evaluate(
                  CurvedAnimation(
                    parent: _tofiFloatCtrl,
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
              child: child,
            ),
            child: Image.asset(
              _dogImage,
              height: screenH * .72,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
              ),
            ),

            const Positioned(top: 25, left: 25, child: ForestXButton()),

            Positioned(
              top: 25,
              right: 25,
              child: ForestLevelBadge(level: widget.level),
            ),

            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: _buildRoundIndicator(),
            ),

            Positioned.fill(
              top: 50,
              bottom: 50,
              child: Column(
                children: [
                  Expanded(
                    flex: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMailbox('A'),
                        _buildMailbox('B'),
                        _buildMailbox('C'),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: Center(child: _buildLetter())),
                ],
              ),
            ),

            buildTofi(context),
          ],
        );
      },
    );
  }

  Widget _buildLetter() {
    if (_parcelDelivered) {
      // Parcel has just been delivered — leave the slot empty until the
      // next round's parcel appears.
      return const SizedBox(width: 150, height: 150);
    }

    final parcelCard = _ParcelCard(
      letter: _displayLetter,
      imagePath: _envelopImage,
    );

    return Draggable<String>(
      data: _displayLetter,
      maxSimultaneousDrags: _canDrag ? 1 : 0,
      feedback: Transform.scale(
        scale: 1.15,
        child: Material(
          color: Colors.transparent,
          child: _ParcelCard(
            letter: _displayLetter,
            imagePath: _envelopImage,
            elevated: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: parcelCard),
      child: parcelCard,
    );
  }

  Widget _buildMailbox(String letter) {
    final isBouncing = _bouncingMailbox == letter;
    final isShaking = _shakingMailbox == letter;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => _canDrag,
      onAcceptWithDetails: (details) => _handleDrop(letter, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        Widget mailbox = _MailboxWidget(
          letter: letter,
          imagePath: _mailboxImage,
          highlighted: isHovering,
        );

        if (isBouncing) {
          return AnimatedBuilder(
            animation: _mailboxBounceController,
            builder: (context, child) {
              final t = _mailboxBounceController.value;
              final scale = 1.0 + (sin(t * pi) * 0.18);
              return Transform.scale(scale: scale, child: child);
            },
            child: mailbox,
          );
        }

        if (isShaking) {
          return AnimatedBuilder(
            animation: _mailboxShakeController,
            builder: (context, child) {
              final t = _mailboxShakeController.value;
              final dx = sin(t * pi * 4) * 8 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: mailbox,
          );
        }

        return mailbox;
      },
    );
  }

  Widget _buildRoundIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalRounds, (i) {
        final done = i < _currentRound;
        final current = i == _currentRound && _currentRound < _totalRounds;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: done
                ? ForestColorTheme.darkseagreen
                : current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// _ParcelCard — the draggable letter parcel, rendered on top of the
/// envelope artwork (assets/images/objects/forest/envelop.png).
/// ─────────────────────────────────────────────────────────────────────────
class _ParcelCard extends StatelessWidget {
  final String letter;
  final String imagePath;
  final bool elevated;

  const _ParcelCard({
    required this.letter,
    required this.imagePath,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.35 : 0.18),
            blurRadius: elevated ? 18 : 8,
            offset: Offset(0, elevated ? 10 : 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(imagePath, fit: BoxFit.contain),
          Text(
            letter,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6B4226),
              shadows: [
                Shadow(
                  color: Colors.white70,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// _MailboxWidget — a drop-target mailbox rendered on top of the mailbox
/// artwork (assets/images/objects/forest/mailbox.png).
/// ─────────────────────────────────────────────────────────────────────────
class _MailboxWidget extends StatelessWidget {
  final String letter;
  final String imagePath;
  final bool highlighted;

  const _MailboxWidget({
    required this.letter,
    required this.imagePath,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: highlighted ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: 140,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(imagePath, fit: BoxFit.contain),

            if (highlighted)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ForestColorTheme.darkseagreen.withValues(
                          alpha: 0.55,
                        ),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              top: 50,
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(1, 2),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}