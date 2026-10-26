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
    bool completed;

    _IcePath(
        {required this.number, required this.slot, this.completed = false});
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

    late List<int> _sequence;
    late List<_IcePath> _icePaths;
    late AnimationController _penguinMoveCtrl;
    late AnimationController _penguinCelebrateCtrl;
    late Animation<double> _penguinCelebrateScale;

    int _currentIndex = 0;
    int? _shakingId;
    int get _target => _sequence[_currentIndex];

    bool _roundWon = false;
    bool _canInteract = false;
    bool _isProcessing = false;

    Timer? _shakeResetTimer;
    Animation<Offset>? _penguinMoveAnim;
    Offset? _penguinPos;

    double _iceSize(double w, double h) {
      const refCols = 4;
      const refRows = 3;
      return min(w / refCols, (h * 0.62) / refRows) * 1.2;
    }

    double _w = 0;
    double _h = 0;

    Offset _slotPos(int slot, double w, double h) {
      final s = _iceSize(w, h);
      final stepX = s * 1.3;
      final stepY = s * 0.8;

      final row = slot ~/ 4;
      var col = slot % 4;
      if (row.isOdd) col = 3 - col;

      final gridW = 3 * stepX;
      final gridH = 2 * stepY;
      final x0 = w / 2 - gridW / 2;
      final yBottom = h * 0.55 + gridH / 2;

      return Offset((x0 + col * stepX) / w, (yBottom - row * stepY) / h);
    }

    Offset _startPos(double w, double h) {
      final first = _slotPos(0, w, h);
      final x = first.dx * w - _iceSize(w, h) * 1.0;
      return Offset((x / w).clamp(0.05, 1.0), first.dy);
    }

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
        startIdleTimer();
      });
    }

    Future<void> _playInstruction() async {
      _canInteract = false;

      await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioInstruction);

      if (!mounted) return;

      if (widget.instructionAudio.isNotEmpty) {
        await playVoiceRestartingOnFaceLoss(_audioPlayer, 
          widget.instructionAudio.replaceFirst(
            'assets/',
            '',
          ),
        );
      }
    }

    void _startRound() {
      _sequence = [for (int n = widget.minNumber; n <= widget.maxNumber; n++) n];
      _currentIndex = 0;
      _roundWon = false;
      _penguinPos = null;
      _icePaths = [
        for (int i = 0; i < _sequence.length; i++)
          _IcePath(number: _sequence[i], slot: i),
      ];
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
        GamesSfxPlayer.instance.play(GameSfx.bubblePop);
        showDomaReaction(DomaState.wrong);
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

      final target = _slotPos(icePath.slot, _w, _h);

      _penguinMoveAnim = Tween<Offset>(
        begin: _penguinPos ?? _startPos(_w, _h),
        end: target,
      ).animate(
        CurvedAnimation(
          parent: _penguinMoveCtrl,
          curve: Curves.easeInOutCubic,
        ),
      );

      await _penguinMoveCtrl.forward(from: 0);

      if (!mounted) return;

      setState(() {
        _penguinPos = target;
      });

      showDomaReaction(DomaState.correct);

      if (!mounted) return;

      await playVoiceRestartingOnFaceLoss(_audioPlayer, 'assets/audio/arctic_numberland/${icePath.number}.wav');

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
      startIdleTimer();
    }

    Future<void> _winRound() async {
      if (!mounted) return;

      setState(() {
        _roundWon = true;
        _canInteract = false;
        _isProcessing = true;
      });

      cancelIdleTimer();

      _penguinCelebrateCtrl.forward(from: 0);

      await playVoiceRestartingOnFaceLoss(_audioPlayer, _audioMahusay);

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
      _audioPlayer.dispose();
      _domaPlayer.dispose();
      disposeIdleTimer();
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
            _w = w;
            _h = h;

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
                  animation: Listenable.merge([_penguinMoveCtrl, _penguinCelebrateCtrl]),
                  builder: (_, __) => _buildPenguin(w, h),
                ),

                if (showHowToPlay && _canInteract && !_roundWon)
                  Positioned.fill(
                    child: HowToPlayOverlay(
                      previewChild: _buildHintPreview(w, h),
                      handAlignment: _hintHandAlignment(w, h),
                      handOffset: const Offset(0.3, 0.8),
                      onDismiss: resetIdleTimer,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    Alignment _hintHandAlignment(double w, double h) {
      final next = _icePaths.firstWhere((p) => p.number == _target);
      final p = _slotPos(next.slot, w, h);
      return Alignment(p.dx * 2 - 1, p.dy * 2 - 1);
    }

    Widget _buildHintPreview(double w, double h) {
      return Stack(
        children: [
          Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
          ..._icePaths.map((f) => _buildIcePath(f, w, h)),
          _buildPenguin(w, h),
        ],
      );
    }

    Widget _buildIcePath(_IcePath icePath, double w, double h) {
      final size = _iceSize(w, h);
      final p = _slotPos(icePath.slot, w, h);
      final left = (p.dx * w - size / 2).clamp(0.0, w - size);
      final top = (p.dy * h - size / 2).clamp(0.0, h - size);
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
      final size = h * 0.35;
      final iceSize = _iceSize(w, h);
      final animating = _penguinMoveCtrl.isAnimating && _penguinMoveAnim != null;
      final pos = animating
          ? _penguinMoveAnim!.value
          : (_penguinPos ?? _startPos(w, h));

      final iceLeft = (pos.dx * w - iceSize / 2).clamp(0.0, w - iceSize);
      final iceTop = (pos.dy * h - iceSize / 2).clamp(0.0, h - iceSize);
      final iceCenterX = iceLeft + iceSize / 2;
      final iceCenterY = iceTop + iceSize / 2;

      const xShift = 0.25;
      const feetShift = 0.1;

      final left = (iceCenterX + iceSize * xShift - size / 2).clamp(0.0, w - size);
      var top = (iceCenterY + iceSize * feetShift - size).clamp(0.0, h - size);

      // ── Hop ──────────────────────────────────────────────
      const hopHeight = 0.7;
      double scaleX = 1.0;
      double scaleY = 1.0;

      if (animating) {
        final t = _penguinMoveCtrl.value;
        final air = sin(t * pi);
        top -= air * iceSize * hopHeight;

        scaleY = 1.0 + 0.10 * air;
        scaleX = 1.0 - 0.06 * air;

        if (t > 0.85) {
          final s = sin(((t - 0.85) / 0.15) * pi);
          scaleY -= 0.12 * s;
          scaleX += 0.08 * s;
        }
      }

      final celebrate = _roundWon ? _penguinCelebrateScale.value : 1.0;

      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(            
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(
              scaleX * celebrate,
              scaleY * celebrate,
              1.0,
            ),
            child: Image.asset(
              _penguinImage,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Text('🐧', style: TextStyle(fontSize: size * 0.6)),
            ),
          ),
        ),                                
      );
    }
  }
