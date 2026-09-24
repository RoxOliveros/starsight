  import 'dart:async';
  import 'dart:math';
  import 'package:flutter/material.dart';
  import 'package:audioplayers/audioplayers.dart';
  import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
  import '../../ui_layer/arctic_numberland/arctic_theme.dart';
  import 'arctic_game_ui.dart';
  import 'package:StarSight/business_layer/game_tap_tracker.dart';

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
    final Offset pos;
    bool completed;

    _IcePath({required this.number, required this.pos, this.completed = false});
  }

  class _IceNumberPathGameState extends State<IceNumberPathGame>
      with TickerProviderStateMixin {

    static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic_sea2.png';
    static const String _icePathImage = 'assets/images/objects/arctic/ice_path.png';
    static const String _penguinImage = 'assets/images/characters/doma_the_penguin.png';

    static const String _audioInstruction = 'audio/arctic_numberland/ice_path_instruction.wav';
    static const String _audioBubblePop = 'audio/sound_effects/bubble_pop.wav';
    static const String _audioMahusay = 'audio/arctic_numberland/mahusay.wav';

    late List<int> _sequence;
    late List<_IcePath> _icePaths;
    int _currentIndex = 0;
    bool _roundWon = false;
    bool _canInteract = false;
    bool _isProcessing = false;

    int? _shakingId;
    Timer? _shakeResetTimer;

    late AnimationController _penguinMoveCtrl;
    Animation<Offset>? _penguinMoveAnim;
    Offset _penguinPos = const Offset(0.10, 0.90);

    late AnimationController _penguinCelebrateCtrl;
    late Animation<double> _penguinCelebrateScale;

    int get _target => _sequence[_currentIndex];

    @override
    void initState() {
      super.initState();

      _penguinMoveCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );

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

        setState(() {
          _canInteract = true;
        });
      });
    }

    Future<void> _playInstruction() async {
      _canInteract = false;

      await _playAndWait(
        _audioInstruction,
      );

      if (!mounted) return;

      if (widget.instructionAudio.isNotEmpty) {
        await _playAndWait(
          widget.instructionAudio.replaceFirst(
            'assets/',
            '',
          ),
        );
      }
    }

    Future<void> _playAndWait(String asset) async {
      try {
        await widget.player.stop();

        final completed =
            widget.player.onPlayerComplete.first;

        await widget.player.play(
          AssetSource(asset),
        );

        await completed;
      } catch (e) {
        debugPrint('Audio error ($asset): $e');
      }
    }

    void _startRound() {
      _sequence = [for (int n = widget.minNumber; n <= widget.maxNumber; n++) n];
      _currentIndex = 0;
      _roundWon = false;
      _penguinPos = const Offset(0.10, 0.90);
      _icePaths = _generateNonOverlappingIcePaths(_sequence);
    }

    List<_IcePath> _generateNonOverlappingIcePaths(
        List<int> numbers,
        ) {
      final count = numbers.length;

        final cols = min(4, count);
      final rows = (count / cols).ceil();

      const leftMargin = 0.14;
      const rightMargin = 0.86;

      const bottomY = 0.78;
      const topY = 0.28;

      final positions = <Offset>[];

      for (int row = 0; row < rows; row++) {
        final y = rows == 1
            ? 0.65
            : bottomY -
            ((bottomY - topY) * row / (rows - 1));

        final remaining = count - positions.length;
        final itemsInRow = min(cols, remaining);

        for (int col = 0; col < itemsInRow; col++) {
          double x;

          if (itemsInRow == 1) {
            x = 0.5;
          } else {
            x = leftMargin +
                ((rightMargin - leftMargin) *
                    col /
                    (itemsInRow - 1));
          }

          if (row.isOdd) {
            x = 1.0 - x;
          }

          positions.add(
            Offset(x, y),
          );
        }
      }

      return List.generate(
        count,
            (index) {
          return _IcePath(
            number: numbers[index],
            pos: positions[index],
          );
        },
      );
    }

    Future<void> _handleTap(
        _IcePath icePath,
        ) async {
      if (!_canInteract || _isProcessing || _roundWon || icePath.completed) {
        return;
      }

      _isProcessing = true;

      if (icePath.number == _target) {
        widget.tapTracker.recordCorrectTap();

        await _handleCorrect(icePath);
      } else {
        widget.tapTracker.recordMistake();

        await _handleWrong(icePath);
      }
    }

    Future<void> _handleCorrect(
        _IcePath icePath,
        ) async {
      setState(() {
        icePath.completed = true;
        _canInteract = false;
      });

      // Move Doma first
      _penguinMoveAnim = Tween<Offset>(
        begin: _penguinPos,
        end: icePath.pos,
      ).animate(
        CurvedAnimation(
          parent: _penguinMoveCtrl,
          curve: Curves.easeInOutCubic,
        ),
      );

      await _penguinMoveCtrl.forward(from: 0);

      if (!mounted) return;

      setState(() {
        _penguinPos = icePath.pos;
      });

      await _playAndWait(_audioBubblePop);

      if (!mounted) return;

      await _playAndWait('audio/arctic_numberland/${icePath.number}.wav');

      if (!mounted) return;

      if (_currentIndex + 1 >= _sequence.length) {
        await _winRound();
      } else {
        setState(() {
          _currentIndex++;
          _isProcessing = false;
          _canInteract = true;
        });
      }
    }

    Future<void> _handleWrong(
        _IcePath icePath,
        ) async {
      setState(() {
        _canInteract = false;
        _shakingId = icePath.number;
      });

      _shakeResetTimer?.cancel();

      _shakeResetTimer = Timer(
        const Duration(milliseconds: 450),
            () {
          if (mounted) {
            setState(() {
              _shakingId = null;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _canInteract = true;
      });
    }

    Future<void> _winRound() async {
      if (!mounted) return;

      setState(() {
        _roundWon = true;
        _canInteract = false;
        _isProcessing = true;
      });

      _penguinCelebrateCtrl.forward(from: 0);

      await _playAndWait(_audioMahusay);

      await Future.delayed(
        const Duration(milliseconds: 400),
      );

      if (mounted) {
        widget.onComplete();
      }
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
      return Listener(
        onPointerDown: (_) => widget.tapTracker.recordGenericTap(),
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

                ..._icePaths.map((f) => _buildIcePath(f, w, h)),

                AnimatedBuilder(
                  animation: Listenable.merge([
                    _penguinMoveCtrl,
                    _penguinCelebrateCtrl,
                  ]),
                  builder: (_, __) => _buildPenguin(w, h),
                ),
              ],
            );
          },
        ),
      );
    }

    Widget _buildIcePath(_IcePath icePath, double w, double h) {
      final cols = (sqrt(_sequence.length).ceil()).clamp(1, _sequence.length);
      final rows = (_sequence.length / cols).ceil();
      final cellW = w / cols;
      final cellH = (h * 0.62) / rows;
      final size = (min(cellW, cellH) * 1.2);
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
          child: Opacity(opacity: icePath.completed ? 0.55 : 1.0, child: content),
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
            errorBuilder: (_, __, ___) =>
                Text('🐧', style: TextStyle(fontSize: size * 0.6)),
          ),
        ),
      );
    }
  }
