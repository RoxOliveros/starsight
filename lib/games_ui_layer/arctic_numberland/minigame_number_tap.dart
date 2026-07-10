import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../ui_layer/arctic_numberland/arctic_theme.dart';

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
  });

  @override
  State<TapObjectMiniGame> createState() => _TapObjectMiniGameState();
}

class _TapObjectMiniGameState extends State<TapObjectMiniGame>
    with TickerProviderStateMixin {
  static const List<Offset> _slotGrid = [
    Offset(0.60, 0.26),
    Offset(0.82, 0.26),
    Offset(0.60, 0.52),
    Offset(0.82, 0.52),
    Offset(0.60, 0.78),
    Offset(0.82, 0.78),
  ];

  late List<_ObjectSlot> _objectSlots;
  int _tappedTargets = 0;
  int? _wrongSlotId;
  bool _roundWon = false;

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
    final total = (widget.targetCount + widget.decoyCount).clamp(1, _slotGrid.length);
    final positions = List<Offset>.from(_slotGrid)..shuffle(Random());
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
        final objSize = (h * 0.28).clamp(72.0, 120.0);

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(child: _buildBanner(h)),
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
        color: ArcticColorTheme.pictonblue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        widget.instructionText,
        style: TextStyle(
          fontFamily: ArcticAppTextStyles.fredoka,
          fontSize: (h * 0.09).clamp(16.0, 26.0),
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0x55003366), blurRadius: 6, offset: Offset(0, 2))],
        ),
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