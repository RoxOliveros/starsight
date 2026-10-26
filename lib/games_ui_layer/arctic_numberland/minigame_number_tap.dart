import 'dart:math';
import 'package:StarSight/business_layer/app_audio_lifecycle_mixin.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import '../ai_camera_mixin.dart';
import '../how_to_play_overlay.dart';
import '../idle_hint_mixin.dart';
import 'arctic_game_ui.dart';
import 'dart:async';
import 'package:StarSight/business_layer/game_tap_tracker.dart';

class TapObjectMiniGame extends StatefulWidget {
  final String instructionText;
  final String instructionAudio;
  final String targetCountAudio;
  final String targetObjectAudio;
  final String correctObjectAsset;
  final String correctObjectEmoji;
  final List<String> decoyObjectAssets;
  final List<String> decoyObjectEmojis;
  final int targetCount;
  final int decoyCount;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final int level;
  final GameTapTracker tapTracker;

  const TapObjectMiniGame({
    super.key,
    required this.instructionText,
    required this.instructionAudio,
    this.targetCountAudio = '',
    this.targetObjectAudio = '',
    required this.correctObjectAsset,
    this.correctObjectEmoji = '⭐',
    required this.decoyObjectAssets,
    this.decoyObjectEmojis = const ['❔'],
    required this.targetCount,
    this.decoyCount = 1,
    required this.player,
    required this.onComplete,
    required this.level,
    required this.tapTracker, 
  });

  @override
  State<TapObjectMiniGame> createState() => _TapObjectMiniGameState();
}

class _TapObjectMiniGameState extends State<TapObjectMiniGame>
    with TickerProviderStateMixin, AiCameraMixin, AppAudioLifecycleMixin, IdleHintMixin {

  late List<_ObjectSlot> _objectSlots;
  int _tappedTargets = 0;
  int? _wrongSlotId;
  bool _roundWon = false;

  final Random _random = Random();

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  List<AudioPlayer> get lifecyclePlayers => [_audioPlayer];

  static const String _bgImage = 'assets/images/backgrounds/bg_game_arctic.png';

  List<Offset> _generateSlotGrid(int count) {
    final cols = sqrt(count).ceil().clamp(1, count);
    final rows = (count / cols).ceil();
    final cellW = 0.60 / cols;
    final cellH = 0.62 / rows;
    final positions = <Offset>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (positions.length >= count) break;
        final jitterX = (_random.nextDouble() - 0.5) * cellW * 0.3;
        final jitterY = (_random.nextDouble() - 0.5) * cellH * 0.3;
        positions.add(
          Offset(
            (0.38 + c * cellW + cellW / 2 + jitterX).clamp(0.35, 0.98),
            (0.28 + r * cellH + cellH / 2 + jitterY).clamp(0.28, 0.90),
          ),
        );
      }
    }
    return positions;
  }

  late AnimationController _objectWiggleCtrl;

  @override
  void initState() {
    super.initState();
    _objectWiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _generateObjectSlots();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playInstruction());
  }

  Future<void> _playInstruction() async {
    await widget.player.stop();
    try {
      if (widget.targetCountAudio.isNotEmpty) {
        await playVoiceRestartingOnFaceLoss(_audioPlayer, widget.targetCountAudio);
      }
      if (!mounted) return;
      if (widget.targetObjectAudio.isNotEmpty) {
        await playVoiceRestartingOnFaceLoss(_audioPlayer, widget.targetObjectAudio);
      }
    } catch (_) {}
    if (!mounted) return;
    startIdleTimer();
  }

  void _generateObjectSlots() {
    final total = (widget.targetCount + widget.decoyCount).clamp(1, 16);
    final positions = _generateSlotGrid(total)..shuffle(_random);
    final slots = <_ObjectSlot>[];
    for (int i = 0; i < total; i++) {
      final isTarget = i < widget.targetCount.clamp(0, total);
      slots.add(
        _ObjectSlot(
          id: i,
          pos: positions[i],
          isTarget: isTarget,
          asset: isTarget
              ? widget.correctObjectAsset
              : widget.decoyObjectAssets[i % widget.decoyObjectAssets.length],
          emoji: isTarget
              ? widget.correctObjectEmoji
              : widget.decoyObjectEmojis[i % widget.decoyObjectEmojis.length],
        ),
      );
    }
    _objectSlots = slots;
  }

  Future<void> _onSlotTapped(_ObjectSlot slot) async {
    if (slot.tapped || _roundWon) return;

    // replace the `if (slot.isTarget) { ... }` block
    if (slot.isTarget) {
      widget.tapTracker.recordCorrectTap();
      setState(() {
        slot.tapped = true;
        _tappedTargets++;
      });

      if (_tappedTargets >= widget.targetCount) {
        setState(() => _roundWon = true);
        cancelIdleTimer();
        try {
          await playVoiceRestartingOnFaceLoss(
            _audioPlayer,
            'assets/audio/arctic_numberland/$_tappedTargets.wav',
          );
          if (!mounted) return;
          await playVoiceRestartingOnFaceLoss(
            _audioPlayer,
            'assets/audio/arctic_numberland/mahusay.wav',
          );
        } catch (_) {}
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) widget.onComplete();
      } else {
        unawaited(
          playVoiceRestartingOnFaceLoss(
            _audioPlayer,
            'assets/audio/arctic_numberland/$_tappedTargets.wav',
          ).catchError((_) {}),
        );
      }
    } else {
      widget.tapTracker.recordMistake();
      setState(() => _wrongSlotId = slot.id);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _wrongSlotId = null);
    }
  }

  @override
  void dispose() {
    disposeIdleTimer();
    _objectWiggleCtrl.dispose();
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
          final objSize = _objSize(h);
          return Stack(
            children: [
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
              ..._objectSlots.map(
                (slot) => _buildObjectSlot(slot, w, h, objSize),
              ),
              if (showHowToPlay && !_roundWon)
                Positioned.fill(
                  child: HowToPlayOverlay(
                    previewChild: _buildHintPreview(w, h, objSize),
                    handAlignment: _hintHandAlignment(w, h, objSize),
                    handOffset: const Offset(0.3, 0.4),
                    onDismiss: resetIdleTimer,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _objSize(double h) =>
      (h * 0.38 / (sqrt(widget.targetCount + widget.decoyCount) * 0.6))
          .clamp(72.0, 160.0);

  Alignment _hintHandAlignment(double w, double h, double objSize) {
    final slot = _objectSlots.firstWhere((s) => s.isTarget && !s.tapped);
    final left = (slot.pos.dx * w - objSize / 2).clamp(w * 0.35, w - objSize);
    final top = (slot.pos.dy * h - objSize / 2).clamp(h * 0.28, h - objSize);
    return Alignment(
      (left + objSize / 2) / w * 2 - 1,
      (top + objSize / 2) / h * 2 - 1,
    );
  }

  Widget _buildHintPreview(double w, double h, double objSize) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(_bgImage, fit: BoxFit.cover)),
        ..._objectSlots.map((s) => _buildObjectSlot(s, w, h, objSize)),
      ],
    );
  }

  Widget _buildObjectSlot(
    _ObjectSlot slot,
    double w,
    double h,
    double objSize,
  ) {
    final left = (slot.pos.dx * w - objSize / 2).clamp(w * 0.35, w - objSize);
    final top = (slot.pos.dy * h - objSize / 2).clamp(h * 0.28, h - objSize);
    final wrong = _wrongSlotId == slot.id;

    return Positioned(
      key: ValueKey(slot.id),
      left: left,
      top: top,
      child: AnimatedScale(
        scale: slot.tapped ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _objectWiggleCtrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              0,
              (_objectWiggleCtrl.value - 0.5) * (slot.isTarget ? 10 : -10),
            ),
            child: child,
          ),
          child: GestureDetector(
            onTap: () => _onSlotTapped(slot),
            child: Container(
              width: objSize,
              height: objSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArcticColorTheme.pictonblue.withValues(
                  alpha: slot.isTarget ? 1.0 : 0.85,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ArcticColorTheme.pictonblue.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: wrong ? Colors.red : Colors.white,
                  width: wrong ? 4 : 3,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(objSize * 0.12),
                child: Image.asset(
                  slot.asset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Text(slot.emoji, style: const TextStyle(fontSize: 40)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectSlot {
  final int id;
  final Offset pos;
  final bool isTarget;
  final String asset;
  final String emoji;
  bool tapped;

  _ObjectSlot({
    required this.id,
    required this.pos,
    required this.isTarget,
    required this.asset,
    required this.emoji,
    this.tapped = false,
  });
}
