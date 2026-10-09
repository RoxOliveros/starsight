import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CharacterEntrance extends StatefulWidget {
  final String characterImagePath;
  final String plateImagePath;
  final String? primaryItemOverlayImagePath;
  final String? secondaryItemImagePath;
  final double characterHeightFraction;
  final double characterAspectRatio;
  final double plateWidthFraction;
  final double plateHeightFraction;
  final double plateOffsetXFraction;
  final double secondaryItemWidthFraction;
  final double? secondaryItemHeightFraction;
  final double? secondaryItemOffsetXFraction;
  final AxisDirection from;
  final Duration walkDuration;
  final Duration stepDuration;
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
    final double characterWidthPx = characterHeightPx * widget.characterAspectRatio;
    final double plateWidthPx = sw * widget.plateWidthFraction;
    final double plateBottomPx = characterHeightPx * widget.plateHeightFraction;
    final double plateOffsetXPx = characterWidthPx * widget.plateOffsetXFraction;
    final double secondaryWidthPx = sw * widget.secondaryItemWidthFraction;
    final double secondaryBottomPx = characterHeightPx * (widget.secondaryItemHeightFraction ?? widget.plateHeightFraction);
    final double secondaryOffsetXPx = characterWidthPx * (widget.secondaryItemOffsetXFraction ?? -widget.plateOffsetXFraction);
    final double bounceHeightPx = characterHeightPx * widget.bounceHeightFraction;
    final double startX = widget.from == AxisDirection.right
        ? sw
        : (widget.from == AxisDirection.left ? -sw : 0);
    final int stepCount = (widget.walkDuration.inMilliseconds / widget.stepDuration.inMilliseconds).round().clamp(2, 10);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value;
        final double easedT = Curves.easeOutCubic.transform(t);
        final double dx = startX * (1 - easedT);
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
                  color: Colors.pink.withValues(alpha: 0.5),
                ),
              ),
            ),

            Positioned(
              bottom: plateBottomPx,
              child: Transform.translate(
                offset: Offset(dx + plateOffsetXPx, -bounce * 0.7),
                child: Stack(
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