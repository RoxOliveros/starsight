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

class PenguinSnowflakesMiniGame extends StatefulWidget {
  final int number;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final int level;
  final GameTapTracker tapTracker;

  const PenguinSnowflakesMiniGame({
    super.key,
    required this.number,
    required this.player,
    required this.onComplete,
    required this.level,
    required this.tapTracker,
  });

  @override
  State<PenguinSnowflakesMiniGame> createState() => _PenguinSnowflakesMiniGameState();
}

class _PenguinSnowflakesMiniGameState extends State<PenguinSnowflakesMiniGame>
    with TickerProviderStateMixin, AiCameraMixin, AppAudioLifecycleMixin, IdleHintMixin {

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowflakeImage = 'assets/images/objects/arctic/snowflake.png';
  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';
  static const double _penguinAspect = 0.8;
  static const double _bellyAlignY = 1;

  static const String _audioMahusay = 'assets/audio/arctic_numberland/mahusay.wav';

  static const int _rounds = 3;
  int get _maxNum => max(widget.number, 3);
  int _delivered = 0;
  late int _target;

  String get _snowflakeRequestAudio => 'assets/audio/arctic_numberland/snowflake_$_target.wav';

  final Random _random = Random();
  final List<_FallingSnowflake> _flakes = [];
  int _nextId = 0;
  bool _roundWon = false;
  bool _basketHovered = false;

  Timer? _spawnTimer;
  Timer? _gameTimer;

  late AnimationController _penguinCelebrateCtrl;
  late Animation<double> _penguinCelebrateScale;

  double get _fallSpeed => (0.0016 + widget.number * 0.00016).clamp(0.0016, 0.0042);
  int get _spawnIntervalMs => (1400 - widget.number * 75).clamp(600, 1400).toInt();
  double get _flakeSizeFactor => (0.15 - widget.number * 0.004).clamp(0.095, 0.15);
  int get _maxOnScreen => (4 + (widget.number / 2).ceil()).clamp(4, 9);

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

    _target = _random.nextInt(_maxNum) + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playInstruction();

      if (!mounted) return;
      _startGameLoops();
      startIdleTimer();
    });
  }

  Future<void> _playInstruction() async {
    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _snowflakeRequestAudio);
    } catch (e) {
      debugPrint('Snowflake request audio error: $e');
    }
  }

  void _startGameLoops() {
    _spawnTimer = Timer.periodic(
      Duration(milliseconds: _spawnIntervalMs),
      (_) => _spawnFlake(),
    );
    _gameTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _updateFlakePositions(),
    );
    _spawnFlake();
  }

  void _spawnFlake() {
    if (!mounted || _roundWon || showHowToPlay) return;
    final active = _flakes.where((f) => !f.dragging).length;
    if (active >= _maxOnScreen) return;

    final targetOnScreen = _flakes.any((f) => f.number == _target); 
    final number = targetOnScreen ? _random.nextInt(_maxNum) + 1 : _target; 

    setState(() {
      _flakes.add(
        _FallingSnowflake(
          id: _nextId++,
          number: number, 
          x: 0.08 + _random.nextDouble() * 0.84,
          y: -0.08,
          size: _flakeSizeFactor * (0.85 + _random.nextDouble() * 0.3),
          rotation: _random.nextDouble() * pi * 2,
          speed: _fallSpeed * (0.8 + _random.nextDouble() * 0.4),
        ),
      );
    });
  }

  void _updateFlakePositions() {
    if (!mounted || showHowToPlay) return;
    setState(() {
      for (final f in _flakes) {
        if (f.dragging) continue;
        f.y += f.speed;
      }
      _flakes.removeWhere((f) => !f.dragging && f.y > 1.08);
    });
  }

  Future<void> _handleDelivery(int id) async {
    if (_roundWon) return;
    final flake = _flakes.firstWhere((f) => f.id == id);

    if (flake.number != _target) {
      widget.tapTracker.recordMistake();
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      return;
    }

    widget.tapTracker.recordCorrectTap();
    setState(() {
      _flakes.removeWhere((f) => f.id == id);
      _delivered++;
      if (_delivered >= _rounds) _roundWon = true;
    });

    try {
      GamesSfxPlayer.instance.play(GameSfx.bubblePop);
      await playVoiceRestartingOnFaceLoss(
        _audioPlayer,
        'assets/audio/arctic_numberland/${flake.number}.wav',
      );
    } catch (e) {
      debugPrint('Number audio error: $e');
    }
    if (!mounted) return;

    if (_roundWon) {
      await _winRound();
      return;
    }

    setState(() {
      _flakes.clear();
      _target = _random.nextInt(_maxNum) + 1;
    });
    await _playInstruction();
  }

  Future<void> _winRound() async {
    if (!mounted) return;
    setState(() => _roundWon = true);
    cancelIdleTimer();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _penguinCelebrateCtrl.forward(from: 0);

    try {
      await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioMahusay);
    } catch (e) {
      debugPrint('Mahusay audio error: $e');
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    disposeIdleTimer();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _penguinCelebrateCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

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
          final flakeSize = (h * _flakeSizeFactor * 2);
          final hintFlake = _pickHintFlake();

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(alignment: Alignment.topLeft, child: ArcticXButton()),
                    Align(alignment: Alignment.topRight, child: ArcticLevelBadge(level: widget.level)),
                  ],
                ),
              ),
              Positioned(
                bottom: h * 0.02,
                left: 50,
                child: _buildPenguinTarget(h),
              ),
              ..._flakes.map((f) => _buildDraggableFlake(f, w, h, flakeSize)),
              if (showHowToPlay && !_roundWon && hintFlake != null)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    previewChild: _buildHintPreview(w, h, flakeSize),
                    handAlignment: _flakeAlignment(hintFlake, w, h, flakeSize),
                    handEndAlignment: _penguinAlignment(w, h),
                    handOffset: const Offset(0, 0.4),
                    onDismiss: resetIdleTimer,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  _FallingSnowflake? _pickHintFlake() {
    if (_flakes.any((f) => f.dragging)) return null;
    for (final f in _flakes) {
      if (f.number == _target) return f; 
    }
    return null;
  }

  Alignment _flakeAlignment(_FallingSnowflake f, double w, double h, double size) {
    final left = (f.x * w - size / 2).clamp(0.0, w - size);
    final top = (f.y * h - size / 2).clamp(-size, h - size);
    return Alignment(
      (left + size / 2) / w * 2 - 1,
      (top + size / 2) / h * 2 - 1,
    );
  }

  Alignment _penguinAlignment(double w, double h) {
    final penguinH = h * 0.70;
    final cx = 50 + penguinH * _penguinAspect / 2;
    final cy = h - h * 0.02 - penguinH / 2;
    return Alignment(cx / w * 2 - 1, cy / h * 2 - 1);
  }

  Widget _buildHintPreview(double w, double h, double flakeSize) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        Positioned(
          bottom: h * 0.02,
          left: 50,
          child: IgnorePointer(child: _buildPenguinTarget(h)),
        ),
        ..._flakes.map((f) => _buildDraggableFlake(f, w, h, flakeSize)),
      ],
    );
  }

  Widget _outlinedNumber(int number, double fontSize) {
    final style = TextStyle(
      fontFamily: ArcticAppTextStyles.fredoka,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.none,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          '$number',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.14
              ..strokeJoin = StrokeJoin.round
              ..color = ArcticColorTheme.slateblue,
          ),
        ),
        Text('$number', style: style.copyWith(color: Colors.white)),
      ],
    );
  }

  Widget _buildDraggableFlake(
    _FallingSnowflake f,
    double w,
    double h,
    double size,
  ) {
    final left = (f.x * w - size / 2).clamp(0.0, w - size);
    final top = (f.y * h - size / 2).clamp(-size, h - size);

    final flakeVisual = Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: f.rotation,
          child: Image.asset(
            _snowflakeImage,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Text('❄️', style: TextStyle(fontSize: size * 0.8)),
          ),
        ),
        _outlinedNumber(f.number, size * 0.5), 
      ],
    );

    return Positioned(
      key: ValueKey(f.id),
      left: left,
      top: top,
      child: Draggable<int>(
        data: f.id,
        onDragStarted: () => setState(() => f.dragging = true),
        onDraggableCanceled: (_, __) => setState(() => f.dragging = false),
        onDragEnd: (_) => setState(() => f.dragging = false),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: size, height: size, child: flakeVisual),
        ),
        childWhenDragging: SizedBox(width: size, height: size),
        child: SizedBox(width: size, height: size, child: flakeVisual),
      ),
    );
  }

  Widget _buildPenguinTarget(double h) {
    final penguinH = (h * 0.70);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final accept = !_roundWon;
        if (accept != _basketHovered) {
          setState(() => _basketHovered = accept);
        }
        return accept;
      },
      onLeave: (_) => setState(() => _basketHovered = false),
      onAcceptWithDetails: (details) {
        setState(() => _basketHovered = false);
        _handleDelivery(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedBuilder(
          animation: _penguinCelebrateCtrl,
          builder: (_, child) => Transform.scale(
            scale: _roundWon ? _penguinCelebrateScale.value : 1.0,
            child: child,
          ),
          child: AnimatedScale(
            scale: _basketHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _domaImage,
                  height: penguinH,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Text('🐧', style: TextStyle(fontSize: penguinH * 0.6)),
                ),
                Align(
                  alignment: Alignment(0, _bellyAlignY),
                  child: Transform.translate(
                    offset: Offset(0, penguinH * 0.2),
                    child: _outlinedNumber(_target, penguinH * 0.22),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FallingSnowflake {
  final int id;
  double x;
  double y;
  final double size;
  final double rotation;
  final double speed;
  bool dragging;
  final int number;

  _FallingSnowflake({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.speed,
    this.dragging = false,
    required this.number,
  });
}
