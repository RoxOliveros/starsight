import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable "walk in carrying a plate" entrance for any character.
///
/// We only have a single static image per character (no walk-cycle frames),
/// so the walking feel is simulated with:
///   1. A horizontal slide from off-screen to the resting position.
///   2. A vertical "footstep" bounce (sine wave) layered on top of the
///      slide, tuned to complete whole cycles exactly as the walk finishes
///      — so it lands flat on arrival instead of stopping mid-hop.
///
/// Works for any character — just pass a different [characterImagePath].
/// To re-trigger the same walk-in later (e.g. the fox walking in a second
/// time), hold a `GlobalKey<CharacterEntranceState>` and call `.replay()`.
class CharacterEntrance extends StatefulWidget {
  final String characterImagePath;
  final String plateImagePath;

  /// Character height as a fraction of screen height.
  final double characterHeightFraction;

  /// Plate width as a fraction of screen width.
  final double plateWidthFraction;

  /// Plate vertical position, as a fraction of the character's own height,
  /// measured up from the character's feet — i.e. roughly arm height.
  /// Shared across all characters.
  final double plateHeightFraction;

  /// Plate horizontal position, as a fraction of screen width, measured
  /// from the character's center. Negative = left of center (into the
  /// character's left arm), positive = right of center.
  final double plateOffsetXFraction;

  /// Which side the character walks in from.
  final AxisDirection from;

  final Duration walkDuration;

  /// How long one footstep bounce cycle (down-up) takes — used to derive
  /// how many whole steps fit inside [walkDuration].
  final Duration stepDuration;

  /// How high each bounce hops, as a fraction of character height.
  final double bounceHeightFraction;

  final VoidCallback? onArrived;

  const CharacterEntrance({
    super.key,
    required this.characterImagePath,
    this.plateImagePath = 'assets/images/objects/lumi/plate.png',
    this.characterHeightFraction = 0.65,
    this.plateWidthFraction = 0.12,
    this.plateHeightFraction = 0.30,
    this.plateOffsetXFraction = -0.07,
    this.from = AxisDirection.right,
    this.walkDuration = const Duration(milliseconds: 1800),
    this.stepDuration = const Duration(milliseconds: 260),
    this.bounceHeightFraction = 0.045,
    this.onArrived,
  });

  @override
  State<CharacterEntrance> createState() => CharacterEntranceState();
}

class CharacterEntranceState extends State<CharacterEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.walkDuration,
    );
    _play();
  }

  void _play() {
    _controller.forward(from: 0).whenComplete(() {
      if (mounted && widget.onArrived != null) widget.onArrived!();
    });
  }

  /// Re-runs the walk-in from off-screen. Use this for e.g. the fox
  /// entering a second time: `entranceKey.currentState?.replay();`
  void replay() {
    if (!mounted) return;
    _play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    final double characterHeightPx = sh * widget.characterHeightFraction;
    final double plateWidthPx = sw * widget.plateWidthFraction;
    final double plateBottomPx = characterHeightPx * widget.plateHeightFraction;
    final double plateOffsetXPx = sw * widget.plateOffsetXFraction;
    final double bounceHeightPx =
        characterHeightPx * widget.bounceHeightFraction;

    final double startX = widget.from == AxisDirection.right
        ? sw
        : (widget.from == AxisDirection.left ? -sw : 0);

    // Whole number of footstep half-cycles fit into the walk, so the sine
    // wave always lands back at 0 (feet flat) exactly when t == 1.
    final int stepCount =
        (widget.walkDuration.inMilliseconds /
                widget.stepDuration.inMilliseconds)
            .round()
            .clamp(2, 10);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value; // 0 → 1 across the walk

        // Horizontal slide: eased so the character settles into place.
        final double easedT = Curves.easeOutCubic.transform(t);
        final double dx = startX * (1 - easedT);

        // Footstep bounce: |sin(t * stepCount * pi)| completes `stepCount`
        // half-cycles as t goes 0→1, always landing back at exactly 0.
        final double bounce = t < 1.0
            ? (math.sin(t * stepCount * math.pi)).abs() * bounceHeightPx
            : 0.0;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(dx, -bounce),
              child: Image.asset(
                widget.characterImagePath,
                height: characterHeightPx,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, st) => Container(
                  width: characterHeightPx * 0.55,
                  height: characterHeightPx,
                  color: Colors.pink.withOpacity(0.5),
                ),
              ),
            ),

            // Plate, slid + bounced in lockstep with the character (slightly
            // softer bounce) so it reads as "held" rather than floating
            // independently.
            Positioned(
              bottom: plateBottomPx,
              child: Transform.translate(
                offset: Offset(dx + plateOffsetXPx, -bounce * 0.7),
                child: Image.asset(
                  widget.plateImagePath,
                  width: plateWidthPx,
                  errorBuilder: (ctx, err, st) => Container(
                    width: plateWidthPx,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
