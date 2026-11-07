import 'dart:math' as math;
import 'package:StarSight/ui_layer/alphabet_forest_ui/forest_theme.dart';
import 'package:flutter/material.dart';

//try
/// A honey jar with a counter that bumps whenever the count changes.
/// The jar wobbles and the number pops whenever [count] changes.
class HoneyCounter extends StatefulWidget {
  final int count;
  final int total;
  final GlobalKey jarKey; // used as the star's launch point

  const HoneyCounter({
    super.key,
    required this.count,
    required this.total,
    required this.jarKey,
  });

  @override
  State<HoneyCounter> createState() => _HoneyCounterState();
}

class _HoneyCounterState extends State<HoneyCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didUpdateWidget(HoneyCounter old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _bump.forward(from: 0);
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const jarSize = 90.0; // frame size; the jar itself fills ~55% of it

    // Increased height slightly to 60 to give the widgets room to move without clipping
    return SizedBox(
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // FIX: Use Transform.translate instead of margin to move the pill
          // This prevents the text from getting crumpled by layout constraints.
          Transform.translate(
            // ADJUST BORDER/PILL POSITION HERE:
            // Offset(x, y). Positive 'x' moves right, negative moves left.
            // Positive 'y' moves down, negative moves up. Example: Offset(0, 10) moves it down 10px.
            offset: const Offset(25, -15),
            child: Container(
              // Keep this margin to give space for the jar on the right
              margin: const EdgeInsets.only(right: jarSize * 0.3),
              padding: const EdgeInsets.fromLTRB(16, 4, jarSize * 0.3 + 4, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E3),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDF8B29), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _bump,
                builder: (_, child) {
                  final t = Curves.elasticOut.transform(_bump.value);
                  return Transform.scale(
                    scale: _bump.isAnimating ? 0.8 + 0.2 * t : 1.0,
                    child: child,
                  );
                },
                child: Text(
                  '${widget.count}/${widget.total}',
                  style: const TextStyle(
                    fontFamily: ForestAppTextStyles.fredoka,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ForestColorTheme.darkbrown,
                  ),
                ),
              ),
            ),
          ),

          // FIX: Use Transform.translate to move the jar independently
          Transform.translate(
            // ADJUST HONEY JAR POSITION HERE:
            // Example: Offset(10, -5) moves it right 10px and up 5px.
            offset: const Offset(27, -22),
            child: Image.asset(
              'assets/animations/jar_star.webp',
              key: widget.jarKey,
              width: jarSize,
              height: jarSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small gold star shown on the corner of a completed level tile.
class StarBadge extends StatelessWidget {
  final double size;
  final bool animateIn;
  const StarBadge({super.key, required this.size, this.animateIn = false});

  @override
  Widget build(BuildContext context) {
    // Replaced standard icon with your custom star.png image
    final star = Image.asset(
      'assets/images/icons/star.png',
      width: size,
      height: size,
    );

    if (!animateIn) return star;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.5, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: star,
    );
  }
}

/// Flies a star from [from] to [to] (global screen coords, centers) along an
/// arc, spinning and scaling, then calls [onLanded] and removes itself.
void flyStar({
  required BuildContext context,
  required Offset from,
  required Offset to,
  required double endSize,
  required VoidCallback onLanded,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _StarFlight(
      from: from,
      to: to,
      endSize: endSize,
      onLanded: () {
        entry.remove();
        onLanded();
      },
    ),
  );
  overlay.insert(entry);
}

class _StarFlight extends StatefulWidget {
  final Offset from, to;
  final double endSize;
  final VoidCallback onLanded;
  const _StarFlight({
    required this.from,
    required this.to,
    required this.endSize,
    required this.onLanded,
  });

  @override
  State<_StarFlight> createState() => _StarFlightState();
}

class _StarFlightState extends State<_StarFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onLanded();
      });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _bezier(double t) {
    final a = widget.from, b = widget.to;
    // control point: above the midpoint so the star arcs out of the jar
    final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 70);
    final u = 1 - t;
    return a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final p = _bezier(t);
          // grows out of the jar, peaks mid-flight, settles to badge size
          final s =
              widget.endSize * (0.5 + 1.0 * math.sin(_c.value * math.pi)) +
              widget.endSize * 0.5 * _c.value;
          return Stack(
            children: [
              // sparkle trail
              for (var i = 1; i <= 4; i++)
                if (_c.value - i * 0.05 > 0)
                  Positioned(
                    left: _bezier(_c.value - i * 0.05).dx - 4,
                    top: _bezier(_c.value - i * 0.05).dy - 4,
                    child: Opacity(
                      opacity: (1 - i / 5) * 0.8,
                      child: Container(
                        width: 8 - i.toDouble(),
                        height: 8 - i.toDouble(),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE08A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              Positioned(
                left: p.dx - s / 2,
                top: p.dy - s / 2,
                child: Transform.rotate(
                  angle: _c.value * math.pi * 4,
                  child: StarBadge(size: s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
