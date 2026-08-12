import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'arctic_game_ui.dart';

class IceNumberPathGame extends StatefulWidget {
  final int minNumber;
  final int maxNumber;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final int level;

  final String instructionAudio;

  const IceNumberPathGame({
    super.key,
    required this.minNumber,
    required this.maxNumber,
    required this.player,
    required this.onComplete,
    this.instructionAudio = '',
    required this.level,
  }) : assert(minNumber <= maxNumber);

  @override
  State<IceNumberPathGame> createState() => _IceNumberPathGameState();
}

class _IcePath {
  final int number;
  final Offset pos; // fractional 0..1
  bool completed;

  _IcePath({required this.number, required this.pos, this.completed = false});
}

class _IceNumberPathGameState extends State<IceNumberPathGame>
    with TickerProviderStateMixin {
  final Random _random = Random();

  late List<int> _sequence;
  late List<_IcePath> _icePaths;
  int _currentIndex = 0;
  bool _roundWon = false;

  int? _shakingId;
  Timer? _shakeResetTimer;

  late AnimationController _penguinMoveCtrl;
  Animation<Offset>? _penguinMoveAnim;
  Offset _penguinPos = const Offset(0.10, 0.90);

  late AnimationController _penguinCelebrateCtrl;
  late Animation<double> _penguinCelebrateScale;

  int get _target => _sequence[_currentIndex];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_sea2.png';
  static const String _icePathImage = 'assets/images/objects/arctic/ice_path.png';
  static const String _penguinImage = 'assets/images/characters/doma_the_penguin.png';

  @override
  void initState() {
    super.initState();

    _penguinMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _penguinCelebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _penguinCelebrateScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
    ]).animate(
      CurvedAnimation(parent: _penguinCelebrateCtrl, curve: Curves.easeOut),
    );

    _startRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playInstruction());
  }

  Future<void> _playInstruction() async {
    await widget.player.stop();
    try {
      await widget.player.play(
        AssetSource('audio/arctic_numberland/ice_path_instruction.wav'),
      );
      await widget.player.onPlayerComplete.first;
    } catch (_) {}

    if (widget.instructionAudio.isEmpty) return;
    try {
      await widget.player.play(
        AssetSource(widget.instructionAudio.replaceFirst('assets/', '')),
      );
    } catch (_) {}
  }

  void _startRound() {
    _sequence = [for (int n = widget.minNumber; n <= widget.maxNumber; n++) n];
    _currentIndex = 0;
    _roundWon = false;
    _penguinPos = const Offset(0.10, 0.90);
    _icePaths = _generateNonOverlappingIcePaths(_sequence);
  }

  List<_IcePath> _generateNonOverlappingIcePaths(List<int> numbers) {
    final count = numbers.length;
    final cols = (sqrt(count).ceil()).clamp(1, count);
    final rows = (count / cols).ceil();

    final cellW = 1.0 / cols;
    final cellH = 0.62 / rows;
    const topMargin = 0.24;

    final cells = <Point<int>>[
      for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++) Point(c, r),
    ]..shuffle(_random);

    final shuffledNumbers = List<int>.from(numbers)..shuffle(_random);

    return List.generate(count, (i) {
      final cell = cells[i];
      final jitterX = (_random.nextDouble() - 0.5) * cellW * 0.4;
      final jitterY = (_random.nextDouble() - 0.5) * cellH * 0.4;
      final x = (cell.x * cellW + cellW / 2 + jitterX).clamp(0.06, 0.94);
      final y = (topMargin + cell.y * cellH + cellH / 2 + jitterY)
          .clamp(topMargin, topMargin + 0.54);
      return _IcePath(number: shuffledNumbers[i], pos: Offset(x, y));
    });
  }

  Future<void> _handleTap(_IcePath icePath) async {
    if (_roundWon || icePath.completed) return;

    if (icePath.number == _target) {
      await _handleCorrect(icePath);
    } else {
      _handleWrong(icePath);
    }
  }

  Future<void> _handleCorrect(_IcePath icePath) async {
    setState(() => icePath.completed = true);

    _penguinMoveAnim = Tween<Offset>(
      begin: _penguinPos,
      end: icePath.pos,
    ).animate(CurvedAnimation(parent: _penguinMoveCtrl, curve: Curves.easeInOut));
    await _penguinMoveCtrl.forward(from: 0);
    setState(() => _penguinPos = icePath.pos);

    if (_currentIndex + 1 >= _sequence.length) {
      await _winRound();
    } else {
      setState(() => _currentIndex++);
    }

    try {
      await widget.player.play(AssetSource('audio/sound_effects/bubble_pop.wav'));
      await widget.player.play(AssetSource('audio/arctic_numberland/${icePath.number}.wav'));
      await widget.player.onPlayerComplete.first;
    } catch (_) {}
  }

  void _handleWrong(_IcePath icePath) {
    setState(() => _shakingId = icePath.number);
    _shakeResetTimer?.cancel();
    _shakeResetTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _shakingId = null);
    });

    widget.player
        .play(AssetSource('audio/sound_effects/gentle_no.wav'))
        .catchError((_) {});
  }

  Future<void> _winRound() async {
    setState(() => _roundWon = true);
    _penguinCelebrateCtrl.forward(from: 0);

    try {
      await widget.player.play(
        AssetSource('audio/arctic_numberland/mahusay.wav'),
      );
      await widget.player.onPlayerComplete.first;
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _shakeResetTimer?.cancel();
    _penguinMoveCtrl.dispose();
    _penguinCelebrateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _bgImage,
                fit: BoxFit.cover,
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(alignment: Alignment.topLeft, child: ArcticBackButton()),
                  Align(alignment: Alignment.topRight, child: ArcticLevelBadge(level: widget.level)),
                  Center(child: _buildBanner(h)),
                ],
              ),
            ),

            ..._icePaths.map((f) => _buildIcePath(f, w, h)),

            AnimatedBuilder(
              animation: Listenable.merge([_penguinMoveCtrl, _penguinCelebrateCtrl]),
              builder: (_, __) => _buildPenguin(w, h),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBanner(double h) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: ArcticColorTheme.pictonblue.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: ArcticColorTheme.pictonblue.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _roundWon ? 'Great job!' : 'Help Doma go to $_target!',
            style: TextStyle(
              fontFamily: ArcticAppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcePath(_IcePath icePath, double w, double h) {
    final cols = (sqrt(_sequence.length).ceil()).clamp(1, _sequence.length);
    final rows = (_sequence.length / cols).ceil();
    final cellW = w / cols;
    final cellH = (h * 0.62) / rows;
    final size = (min(cellW, cellH) * 0.62).clamp(56.0, 130.0);
    final left = (icePath.pos.dx * w - size / 2).clamp(0.0, w - size);
    final top = (icePath.pos.dy * h - size / 2).clamp(0.0, h - size);

    final isShaking = _shakingId == icePath.number;
    final isNextTarget = !_roundWon && icePath.number == _target;

    Widget content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage(_icePathImage),
          fit: BoxFit.contain,
        ),
      ),
      child: Transform.translate(
        offset: Offset(0, -size * 0.06),
        child: Text(
          '${icePath.number}',
          style: TextStyle(
            fontFamily: ArcticAppTextStyles.fredoka,
            fontSize: size * 0.36,
            fontWeight: FontWeight.bold,
            color: icePath.completed
                ? ArcticColorTheme.pictonblue.withValues(alpha: 0.35)
                : ArcticColorTheme.slateblue,
          ),
        ),
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

    if (isNextTarget) {
      content = AnimatedScale(
        scale: 1.06,
        duration: const Duration(milliseconds: 500),
        child: content,
      );
    }

    return Positioned(
      key: ValueKey(icePath.number),
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _handleTap(icePath),
        child: Opacity(
          opacity: icePath.completed ? 0.55 : 1.0,
          child: content,
        ),
      ),
    );
  }

  Widget _buildPenguin(double w, double h) {
    final size = (h * 0.22).clamp(90.0, 160.0);
    final pos = _penguinMoveCtrl.isAnimating && _penguinMoveAnim != null
        ? _penguinMoveAnim!.value
        : _penguinPos;

    const renderOffsetX = 0.015;
    const renderOffsetY = -0.1;

    final left = ((pos.dx + renderOffsetX) * w - size / 2).clamp(0.0, w - size);
    final top = ((pos.dy + renderOffsetY) * h - size / 2).clamp(0.0, h - size);

    return Positioned(
      left: left,
      top: top,
      child: Transform.scale(
        scale: _roundWon ? _penguinCelebrateScale.value : 1.0,
        child: Image.asset(
          _penguinImage,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text('🐧', style: TextStyle(fontSize: size * 0.6)),
        ),
      ),
    );
  }
}