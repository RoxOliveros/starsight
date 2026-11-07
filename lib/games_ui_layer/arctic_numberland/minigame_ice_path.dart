import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../business_layer/app_audio_lifecycle_mixin.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../ai_camera_mixin.dart';
import '../games_audio_helper.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'package:StarSight/business_layer/game_tap_tracker.dart';
import 'doma_reaction.dart';

class IceNumberPathGame extends StatefulWidget {
  final int minNumber;
  final int maxNumber;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final int level;
  final String instructionAudio;
  final GameTapTracker tapTracker;

  const IceNumberPathGame({
    super.key,
    required this.minNumber,
    required this.maxNumber,
    required this.player,
    required this.onComplete,
    this.instructionAudio = '',
    required this.level,
    required this.tapTracker,
  }) : assert(minNumber <= maxNumber);

  @override
  State<IceNumberPathGame> createState() => _IceNumberPathGameState();
}

class _IcePath {
  final int number;
  final int slot;
  bool filled;

  _IcePath({required this.number, required this.slot, this.filled = false});
}

class _Penguin {
  final int number;
  bool placed;
  bool dragging;

  _Penguin(this.number, {this.placed = false, this.dragging = false});
}

class _IceNumberPathGameState extends State<IceNumberPathGame>
    with
        TickerProviderStateMixin,
        DomaReactionMixin,
        AiCameraMixin,
        AppAudioLifecycleMixin,
        IdleHintMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _domaPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer, _domaPlayer];

  @override
  AudioPlayer get domaPlayer => _domaPlayer;

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_sea2.png';
  static const String _icePathImage = 'assets/images/objects/arctic/ice_path.png';
  static const String _penguinImage = 'assets/images/characters/doma_the_penguin.png';

  static const String _audioInstruction = 'assets/audio/arctic_numberland/ice_path_instruction.wav';
  static const String _audioMahusay = 'assets/audio/arctic_numberland/mahusay.wav';

  static const double _penguinAspect = 0.8;
  static const double _chestAlignY = 0.25;

  final Random _random = Random();

  late List<_IcePath> _icePaths;
  late List<_Penguin> _penguins;
  late AnimationController _penguinCelebrateCtrl;
  late Animation<double> _penguinCelebrateScale;

  int _placed = 0;
  int? _shakingNumber;

  bool _roundWon = false;
  bool _canInteract = false;

  Timer? _shakeResetTimer;

  int get _count => widget.maxNumber - widget.minNumber + 1;
  int get _cols => _count <= 4 ? _count : (_count <= 8 ? 4 : 5);

  // ── Layout ───────────────────────────────────────────────────────────
  double _iceSize(double w, double h) => h * 0.3;

  Offset _iceCenter(int slot, double w, double h) {
    final s = _iceSize(w, h);
    final stepX = s * 1.15;
    final stepY = s * 0.85;

    final row = slot ~/ _cols;
    final col = slot % _cols;
    final inRow = min(_cols, _count - row * _cols);
    final rowW = (inRow - 1) * stepX;

    final x = w / 2 - rowW / 2 + col * stepX;
    final y = h * 0.17 + s / 2 + row * stepY;
    return Offset(x, y);
  }

  double _penguinHeight(double w, double h) {
    final slotMax = w * 0.92 / _count;
    return min(h * 0.26, (slotMax - 8) / _penguinAspect);
  }

  double _slotWidth(double w, double h) =>
      _penguinHeight(w, h) * _penguinAspect + 8;

  double _trayLeft(double w, double h) =>
      (w - _slotWidth(w, h) * _penguins.length) / 2;

  Offset _penguinCenter(int index, double w, double h) {
    final slotW = _slotWidth(w, h);
    final penH = _penguinHeight(w, h);
    return Offset(
      _trayLeft(w, h) + index * slotW + slotW / 2,
      h - h * 0.03 - penH / 2,
    );
  }

  Alignment _align(Offset p, double w, double h) =>
      Alignment(p.dx / w * 2 - 1, p.dy / h * 2 - 1);

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _penguinCelebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _penguinCelebrateScale =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _penguinCelebrateCtrl, curve: Curves.easeOut),
        );

    _startRound();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playInstruction();

      if (!mounted) return;

      setState(() => _canInteract = true);
      startIdleTimer();
    });
  }

  Future<void> _playInstruction() async {
    _canInteract = false;

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioInstruction);

    if (!mounted) return;

    if (widget.instructionAudio.isNotEmpty) {
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        widget.instructionAudio.replaceFirst('assets/', ''),
      );
    }
  }

  void _startRound() {
    final numbers = [
      for (int n = widget.minNumber; n <= widget.maxNumber; n++) n,
    ];

    _icePaths = [
      for (int i = 0; i < numbers.length; i++)
        _IcePath(number: numbers[i], slot: i),
    ];

    final penguinNumbers = [...numbers]..shuffle(_random);
    _penguins = penguinNumbers.map((n) => _Penguin(n)).toList();

    _placed = 0;
    _roundWon = false;
  }

  // ── Gameplay ─────────────────────────────────────────────────────────
  Future<void> _handleDrop(_IcePath ice, int number) async {
    if (_roundWon || ice.filled) return;

    if (number != ice.number) {
      widget.tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      showDomaReaction(DomaState.wrong);

      setState(() => _shakingNumber = ice.number);
      _shakeResetTimer?.cancel();
      _shakeResetTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _shakingNumber = null);
      });
      startIdleTimer();
      return;
    }

    widget.tapTracker.recordCorrectTap();
    final penguin = _penguins.firstWhere((p) => p.number == number);
    setState(() {
      ice.filled = true;
      penguin.placed = true;
      _placed++;
      if (_placed >= _count) _roundWon = true;
    });

    showDomaReaction(DomaState.correct);

    await playVoiceRestartingOnFaceLoss(
      _audioPlayer,
      'assets/audio/arctic_numberland/$number.wav',
    );
    if (!mounted) return;

    if (_roundWon) {
      await _winRound();
    } else {
      startIdleTimer();
    }
  }

  Future<void> _winRound() async {
    if (!mounted) return;

    setState(() {
      _roundWon = true;
      _canInteract = false;
    });

    cancelIdleTimer();

    _penguinCelebrateCtrl.forward(from: 0);

    await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioMahusay);

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _shakeResetTimer?.cancel();
    _penguinCelebrateCtrl.dispose();
    _audioPlayer.dispose();
    _domaPlayer.dispose();
    disposeIdleTimer();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        widget.tapTracker.recordGenericTap();
        resetIdleTimer();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),

              Padding(
                padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(alignment: Alignment.topLeft, child: ArcticXButton()),
                    Align(
                      alignment: Alignment.topRight,
                      child: ArcticLevelBadge(level: widget.level),
                    ),
                  ],
                ),
              ),

              ..._icePaths.map((ice) => _buildIce(ice, w, h)),

              _buildTray(w, h),

              if (showHowToPlay && _canInteract && !_roundWon)
                Positioned.fill(child: _buildHowToPlay(w, h)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHowToPlay(double w, double h) {
    final index = _penguins.indexWhere((p) => !p.placed);
    if (index < 0) return const SizedBox.shrink();

    final number = _penguins[index].number;
    final ice = _icePaths.firstWhere((i) => i.number == number);

    return HowToPlayOverlay(
      previewChild: _buildHintPreview(w, h),
      handAlignment: _align(_penguinCenter(index, w, h), w, h),
      handEndAlignment: _align(_iceCenter(ice.slot, w, h), w, h),
      handOffset: const Offset(0.15, 0.5),
      onDismiss: resetIdleTimer,
    );
  }

  Widget _buildHintPreview(double w, double h) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        ..._icePaths.map((ice) => _buildIce(ice, w, h)),
        _buildTray(w, h),
      ],
    );
  }

  // ── Ice paths (drop targets) ─────────────────────────────────────────
  Widget _buildIce(_IcePath ice, double w, double h) {
    final size = _iceSize(w, h);
    final c = _iceCenter(ice.slot, w, h);
    final isShaking = _shakingNumber == ice.number;

    Widget content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_icePathImage),
                fit: BoxFit.contain,
              ),
            ),
            child: Transform.translate(
              offset: Offset(0, -size * 0.06),
              child: Text(
                '${ice.number}',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.bold,
                  color: ice.filled
                      ? ArcticColorTheme.pictonblue.withValues(alpha: 0.35)
                      : ArcticColorTheme.slateblue,
                ),
              ),
            ),
          ),
          if (ice.filled)
            Positioned(
              left: 0,
              right: 0,
              bottom: size * 0.4,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (_, t, child) => AnimatedBuilder(
                    animation: _penguinCelebrateCtrl,
                    builder: (_, __) => Transform.scale(
                      alignment: Alignment.bottomCenter,
                      scale:
                      t *
                          (_roundWon ? _penguinCelebrateScale.value : 1.0),
                      child: child,
                    ),
                  ),
                  child: Center(child: _penguinChip(ice.number, size * 0.85)),
                ),
              ),
            ),
        ],
      ),
    );

    if (isShaking) {
      content = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (context, t, child) {
          final dx = sin(t * pi * 6) * 6 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: content,
      );
    }

    return Positioned(
      key: ValueKey('ice_${ice.number}'),
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => !ice.filled && !_roundWon,
        onAcceptWithDetails: (details) => _handleDrop(ice, details.data),
        builder: (context, candidate, rejected) => AnimatedScale(
          scale: candidate.isNotEmpty ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: content,
        ),
      ),
    );
  }

  // ── Penguin tray (draggables) ────────────────────────────────────────
  Widget _buildTray(double w, double h) {
    final penH = _penguinHeight(w, h);
    final slotW = _slotWidth(w, h);

    return Positioned(
      left: _trayLeft(w, h),
      bottom: h * 0.03,
      child: Row(
        children: [
          for (final p in _penguins)
            SizedBox(
              key: ValueKey('pen_${p.number}'),
              width: slotW,
              height: penH,
              child: p.placed
                  ? null
                  : Center(
                child: Draggable<int>(
                  data: p.number,
                  maxSimultaneousDrags: _canInteract ? 1 : 0,
                  onDragStarted: () => setState(() => p.dragging = true),
                  onDragEnd: (_) {
                    if (mounted) setState(() => p.dragging = false);
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: _penguinChip(p.number, penH * 1.1),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _penguinChip(p.number, penH),
                  ),
                  child: _penguinChip(p.number, penH),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Penguin with its number on the chest.
  Widget _penguinChip(int number, double height) {
    final badge = height * 0.28;
    return SizedBox(
      width: height * _penguinAspect,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            _penguinImage,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Text('🐧', style: TextStyle(fontSize: height * 0.6)),
          ),
          Align(
            alignment: Alignment(0, _chestAlignY * 2.5),
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ArcticColorTheme.slateblue, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: TextStyle(
                  fontFamily: ArcticAppTextStyles.fredoka,
                  fontSize: badge * 0.65,
                  fontWeight: FontWeight.bold,
                  color: ArcticColorTheme.slateblue,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}