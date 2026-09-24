import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
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
  State<PenguinSnowflakesMiniGame> createState() =>
      _PenguinSnowflakesMiniGameState();
}

class _PenguinSnowflakesMiniGameState extends State<PenguinSnowflakesMiniGame>
    with TickerProviderStateMixin {

  static const String _domaImage = 'assets/images/characters/doma_the_penguin.png';
  static const String _snowflakeImage = 'assets/images/objects/arctic/snowflake.png';

  String get _snowflakeRequestAudio => 'audio/arctic_numberland/snowflake_${widget.number}.wav';
  static const String _audioBubblePop = 'audio/sound_effects/bubble_pop.wav';
  static const String _audioMahusay = 'audio/arctic_numberland/mahusay.wav';

  final Random _random = Random();
  final List<_FallingSnowflake> _flakes = [];
  int _nextId = 0;

  int _delivered = 0;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playInstruction();

      if (!mounted) return;

      _startGameLoops();
    });
  }

  Future<void> _playInstruction() async {
    await widget.player.stop();

    try {
      await widget.player.play(
        AssetSource(_snowflakeRequestAudio),
      );

      await widget.player.onPlayerComplete.first;
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
    if (!mounted || _roundWon) return;
    final active = _flakes.where((f) => !f.dragging).length;
    if (active >= _maxOnScreen) return;

    setState(() {
      _flakes.add(
        _FallingSnowflake(
          id: _nextId++,
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
    if (!mounted) return;
    setState(() {
      for (final f in _flakes) {
        if (f.dragging) continue;
        f.y += f.speed;
      }
      _flakes.removeWhere((f) => !f.dragging && f.y > 1.08);
    });
  }

  Future<void> _handleDelivery(int id) async {
    if (_roundWon || _delivered >= widget.number) return;

    widget.tapTracker.recordCorrectTap();

    if (!mounted) return;
    setState(() {
      _flakes.removeWhere((f) => f.id == id);
      _delivered++;
      if (_delivered >= widget.number) _roundWon = true;
    });

    try {
      await widget.player.play(
        AssetSource(_audioBubblePop),
      );
      await widget.player.play(
        AssetSource('audio/arctic_numberland/$_delivered.wav'),
      );
      await widget.player.onPlayerComplete.first;
    } catch (_) {}

    if (!mounted) return;
    if (_delivered >= widget.number) {
      await _winRound();
    }
  }

  Future<void> _winRound() async {
    if (!mounted) return;
    setState(() => _roundWon = true);
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _penguinCelebrateCtrl.forward(from: 0);

    try {
      await widget.player.play(
        AssetSource(_audioMahusay),
      );
      await widget.player.onPlayerComplete.first;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _penguinCelebrateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final flakeSize = (h * _flakeSizeFactor).clamp(48.0, 100.0);

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: ArcticXButton(),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: ArcticLevelBadge(level: widget.level),
                    ),
                  ],
                ),
              ),
              ..._flakes.map((f) => _buildDraggableFlake(f, w, h, flakeSize)),
              Positioned(
                bottom: h * 0.02,
                left: 50,
                child: Center(child: _buildPenguinTarget(h)),
              ),
            ],
          );
        },
      ),
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

    final flakeVisual = Transform.rotate(
      angle: f.rotation,
      child: Image.asset(
        _snowflakeImage,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text('❄️', style: TextStyle(fontSize: size * 0.8)),
      ),
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
            child: Image.asset(
              _domaImage,
              height: penguinH,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Text('🐧', style: TextStyle(fontSize: penguinH * 0.6)),
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

  _FallingSnowflake({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.speed,
    this.dragging = false,
  });
}
