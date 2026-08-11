import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_buttons.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';
import 'arctic_game_ui.dart';

/// A "tap N of the correct object, avoid the decoys" mini-game.
/// Fully self-contained — plug it into any NumberLevelConfig via
/// miniGameBuilder, or write a different mini-game widget with the same
/// {player, onComplete} shape and swap it in instead.
class TapObjectMiniGame extends StatefulWidget {
  final String instructionText;
  final String instructionAudio;
  final String correctObjectAsset;
  final String correctObjectEmoji;
  final List<String> decoyObjectAssets;
  final String decoyObjectEmoji;
  final int targetCount;
  final int decoyCount;
  final AudioPlayer player;
  final VoidCallback onComplete;
  final int level;

  const TapObjectMiniGame({
    super.key,
    required this.instructionText,
    required this.instructionAudio,
    required this.correctObjectAsset,
    this.correctObjectEmoji = '⭐',
    required this.decoyObjectAssets,
    this.decoyObjectEmoji = '❔',
    required this.targetCount,
    this.decoyCount = 1,
    required this.player,
    required this.onComplete,
    required this.level,
  });

  @override
  State<TapObjectMiniGame> createState() => _TapObjectMiniGameState();
}

class _TapObjectMiniGameState extends State<TapObjectMiniGame>
    with TickerProviderStateMixin {
  late List<_ObjectSlot> _objectSlots;
  int _tappedTargets = 0;
  int? _wrongSlotId;
  bool _roundWon = false;

  final Random _random = Random();

  List<Offset> _generateSlotGrid(int count) {
    final cols = sqrt(count).ceil().clamp(1, count);
    final rows = (count / cols).ceil();
    final cellW = 0.40 / cols;   // objects live in right ~40% of width
    final cellH = 0.62 / rows;   // matches ice-path game's vertical band
    final positions = <Offset>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (positions.length >= count) break;
        final jitterX = (_random.nextDouble() - 0.5) * cellW * 0.3;
        final jitterY = (_random.nextDouble() - 0.5) * cellH * 0.3;
        positions.add(Offset(
          (0.58 + c * cellW + cellW / 2 + jitterX).clamp(0.55, 0.96),
          (0.20 + r * cellH + cellH / 2 + jitterY).clamp(0.20, 0.85),
        ));
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
    try {
      await widget.player.play(
        AssetSource(widget.instructionAudio.replaceFirst('assets/', '')),
      );
    } catch (_) {}
  }

  void _generateObjectSlots() {
    final total = widget.targetCount + widget.decoyCount;
    final positions = _generateSlotGrid(total)..shuffle(_random);
    final slots = <_ObjectSlot>[];
    for (int i = 0; i < total; i++) {
      final isTarget = i < widget.targetCount;
      slots.add(_ObjectSlot(
        id: i,
        pos: positions[i],
        isTarget: isTarget,
        asset: isTarget
            ? widget.correctObjectAsset
            : widget.decoyObjectAssets[i % widget.decoyObjectAssets.length],
        emoji: isTarget ? widget.correctObjectEmoji : widget.decoyObjectEmoji,
      ));
    }
    _objectSlots = slots;
  }

  Future<void> _onSlotTapped(_ObjectSlot slot) async {
    if (slot.tapped || _roundWon) return;

    if (slot.isTarget) {
      setState(() {
        slot.tapped = true;
        _tappedTargets++;
      });
      try {
        await widget.player.play(
          AssetSource('audio/arctic_numberland/pop.wav'),
        );
      } catch (_) {}
      if (_tappedTargets >= widget.targetCount) {
        setState(() => _roundWon = true);
        widget.onComplete();
      }
    } else {
      setState(() => _wrongSlotId = slot.id);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _wrongSlotId = null);
    }
  }

  @override
  void dispose() {
    _objectWiggleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final objSize = (h * 0.28 / (sqrt(widget.targetCount + widget.decoyCount) * 0.6)).clamp(48.0, 120.0);

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 25),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(alignment: Alignment.topLeft, child: ArcticBackButton()),
                  Align(alignment: Alignment.topRight, child: ArcticLevelBadge(level: widget.level)),
                  Align(alignment: Alignment.topCenter, child: _buildBanner(h)),
                ],
              ),
            ),
            ..._objectSlots.map((slot) => _buildObjectSlot(slot, w, h, objSize)),
          ],
        );
      },
    );
  }

  Widget _buildBanner(double h) {
    return Container(
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
        widget.instructionText,
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],        ),
      ),
    );
  }

  Widget _buildObjectSlot(_ObjectSlot slot, double w, double h, double objSize) {
    final left = (slot.pos.dx * w - objSize / 2).clamp(w * 0.55, w - objSize);
    final top = (slot.pos.dy * h - objSize / 2).clamp(h * 0.22, h - objSize);
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
            offset: Offset(0, (_objectWiggleCtrl.value - 0.5) * (slot.isTarget ? 10 : -10)),
            child: child,
          ),
          child: GestureDetector(
            onTap: () => _onSlotTapped(slot),
            child: Container(
              width: objSize,
              height: objSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArcticColorTheme.pictonblue.withValues(alpha: slot.isTarget ? 1.0 : 0.85),
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
                  errorBuilder: (_, __, ___) => Text(slot.emoji, style: const TextStyle(fontSize: 40)),
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