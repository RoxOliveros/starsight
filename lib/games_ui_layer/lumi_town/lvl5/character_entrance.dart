import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable "walk in carrying a plate + drink" entrance for any character.
///
/// We only have a single static image per character (no walk-cycle frames),
/// so the walking feel is simulated with:
///   1. A horizontal slide from off-screen to the resting position.
///   2. A vertical "footstep" bounce (sine wave) layered on top of the
///      slide, tuned to complete whole cycles exactly as the walk finishes
///      — so it lands flat on arrival instead of stopping mid-hop.
///
/// The character carries two independent items, one per arm:
///   - [plateImagePath] (always shown) with an optional
///     [primaryItemOverlayImagePath] (e.g. food) layered on top once given.
///   - An optional [secondaryItemImagePath] (e.g. a water glass) on the
///     other arm, only rendered while non-null.
///
/// Both items are positioned as a fraction of the *character's own*
/// rendered size (via [characterAspectRatio]) rather than the raw screen
/// size — this is what keeps them anchored to the arms instead of drifting
/// toward the face/center on different screen aspect ratios.
///
/// Works for any character — just pass a different [characterImagePath].
/// To re-trigger the same walk-in later (e.g. the fox walking in a second
/// time), hold a `GlobalKey<CharacterEntranceState>` and call `.replay()`.
class CharacterEntrance extends StatefulWidget {
  final String characterImagePath;
  final String plateImagePath;

  /// Overlay shown on top of the plate once food has been given (e.g. the
  /// pancake stack). Leave null while nothing has been given yet.
  final String? primaryItemOverlayImagePath;

  /// Item held in the character's *other* arm (e.g. a water glass). Only
  /// rendered while non-null, so pass null until it's been given.
  final String? secondaryItemImagePath;

  /// Character height as a fraction of screen height.
  final double characterHeightFraction;

  /// Rough width/height ratio of the character artwork. Used to convert
  /// arm offsets into something proportional to the character itself
  /// rather than the raw screen width, so held items land on the arm
  /// instead of drifting toward the screen edge (wide screens) or the
  /// face (narrow screens). Tune per character if the art is unusually
  /// wide or narrow.
  final double characterAspectRatio;

  /// Plate width as a fraction of screen width.
  final double plateWidthFraction;

  /// Plate/food vertical position, as a fraction of the character's own
  /// height, measured up from the character's feet. Most of these mascot
  /// characters are drawn "chibi" style with an oversized head, so the
  /// hands sit much lower than half height — keep this well under 0.3 or
  /// the plate ends up at cheek height. Tune per character if needed.
  final double plateHeightFraction;

  /// Plate/food horizontal position, as a fraction of the character's own
  /// (rendered) width, measured from the character's center.
  /// Negative = character's right arm / screen-left.
  /// Positive = character's left arm / screen-right.
  final double plateOffsetXFraction;

  /// Secondary (water) item width, as a fraction of screen width.
  final double secondaryItemWidthFraction;

  /// Secondary item vertical position. Defaults to [plateHeightFraction]
  /// so both hands sit at the same height.
  final double? secondaryItemHeightFraction;

  /// Secondary item horizontal position. Defaults to the mirror of
  /// [plateOffsetXFraction] so it lands on the opposite arm automatically.
  final double? secondaryItemOffsetXFraction;

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
    this.primaryItemOverlayImagePath,
    this.secondaryItemImagePath,
    this.characterHeightFraction = 0.65,
    this.characterAspectRatio = 0.6,
    this.plateWidthFraction = 0.12,
    this.plateHeightFraction = 0.24,
    this.plateOffsetXFraction = -0.55,
    this.secondaryItemWidthFraction = 0.08,
    this.secondaryItemHeightFraction,
    this.secondaryItemOffsetXFraction,
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
    final double characterWidthPx =
        characterHeightPx * widget.characterAspectRatio;

    final double plateWidthPx = sw * widget.plateWidthFraction;
    final double plateBottomPx = characterHeightPx * widget.plateHeightFraction;
    final double plateOffsetXPx =
        characterWidthPx * widget.plateOffsetXFraction;

    final double secondaryWidthPx = sw * widget.secondaryItemWidthFraction;
    final double secondaryBottomPx =
        characterHeightPx *
        (widget.secondaryItemHeightFraction ?? widget.plateHeightFraction);
    final double secondaryOffsetXPx =
        characterWidthPx *
        (widget.secondaryItemOffsetXFraction ?? -widget.plateOffsetXFraction);

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

            // Plate (+ food once given), held in one arm — slid + bounced
            // in lockstep with the character (slightly softer bounce) so
            // it reads as "held" rather than floating independently.
            Positioned(
              bottom: plateBottomPx,
              child: Transform.translate(
                offset: Offset(dx + plateOffsetXPx, -bounce * 0.7),
                child: Stack(
                  // Bottom-aligned so the food's base rests on the plate's
                  // surface instead of being centered through the middle of
                  // it (which made it look like it was sinking into /
                  // overlapping the plate rather than sitting on top).
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
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
                    if (widget.primaryItemOverlayImagePath != null)
                      Padding(
                        // Small lift off the very bottom edge so the food
                        // reads as resting ON the plate rather than hanging
                        // off its front rim. Tune this if the plate art has
                        // a lot of transparent margin at the bottom.
                        padding: EdgeInsets.only(bottom: plateWidthPx * 0.08),
                        child:
                            Image.asset(
                              widget.primaryItemOverlayImagePath!,
                              width: plateWidthPx * 0.8,
                            ).animate().scale(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                            ),
                      ),
                  ],
                ),
              ),
            ),

            // Secondary item (e.g. water), held in the *other* arm — only
            // rendered once given.
            if (widget.secondaryItemImagePath != null)
              Positioned(
                bottom: secondaryBottomPx,
                child: Transform.translate(
                  offset: Offset(dx + secondaryOffsetXPx, -bounce * 0.7),
                  child:
                      Image.asset(
                        widget.secondaryItemImagePath!,
                        width: secondaryWidthPx,
                        errorBuilder: (ctx, err, st) => Container(
                          width: secondaryWidthPx,
                          height: secondaryWidthPx * 1.4,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ).animate().scale(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}
