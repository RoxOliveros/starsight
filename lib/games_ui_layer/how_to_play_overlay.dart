import 'package:flutter/material.dart';

class HowToPlayOverlay extends StatefulWidget {
  final Widget? previewChild;
  final Widget Function(double dragT)? previewBuilder;
  final Alignment handAlignment;
  final Alignment? handEndAlignment;
  final Offset handOffset;
  final VoidCallback? onDismiss;
  final bool tapSequence;
  final List<Alignment>? handPath;
  final bool showHand;

  const HowToPlayOverlay({
    super.key,
    this.previewChild,
    this.previewBuilder,
    required this.handAlignment,
    this.handEndAlignment,
    this.handPath,
    this.handOffset = Offset.zero,
    this.onDismiss,
    this.tapSequence = false,
    this.showHand = true,
  }) : assert(previewChild != null || previewBuilder != null);

  static const String _handAsset =
      'assets/images/objects/lagoon/pointing_hand.png';

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl;

  bool get _isSequence => widget.tapSequence && widget.handEndAlignment != null;

  bool get _isPathSequence =>
      widget.tapSequence &&
      widget.handPath != null &&
      widget.handPath!.length >= 2;

  bool get _isDrag =>
      (widget.handEndAlignment != null || widget.handPath != null) &&
      !widget.tapSequence;

  double _dragProgress(double t) =>
      Curves.easeInOut.transform(((t - 0.2) / 0.55).clamp(0.0, 1.0));

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: _isPathSequence
            ? 1300 * widget.handPath!.length
            : (_isDrag ? 2200 : (_isSequence ? 2600 : 900)),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  double _tapValue(double t) {
    if (t < 0.4) return Curves.easeOut.transform(t / 0.4);
    if (t < 0.6) return 1.0;
    return 1.0 - Curves.easeIn.transform((t - 0.6) / 0.4);
  }

  Alignment _alongPath(List<Alignment> path, double t) {
    final pos = t.clamp(0.0, 1.0) * (path.length - 1);
    final i = pos.floor().clamp(0, path.length - 2);
    return Alignment.lerp(path[i], path[i + 1], pos - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            width: screenSize.width * 0.55,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey, width: 6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: screenSize.width / screenSize.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: screenSize.width,
                            height: screenSize.height,
                            child: widget.previewBuilder == null
                                ? widget.previewChild!
                                : AnimatedBuilder(
                                    animation: _tapCtrl,
                                    builder: (_, __) => widget.previewBuilder!(
                                      _dragProgress(_tapCtrl.value),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showHand)
                      AnimatedBuilder(
                        animation: _tapCtrl,
                        builder: (_, child) {
                          final t = _tapCtrl.value;
                          var align = widget.handAlignment;
                          var liftY = 0.0;
                          var scale = 1.0;

                          if (_isPathSequence) {
                            final path = widget.handPath!;
                            final n = path.length;
                            final scaled = (t * n).clamp(0.0, n - 0.0001);
                            final k = scaled.floor();
                            final u = scaled - k;
                            final next = path[(k + 1) % n];

                            if (u < 0.65) {
                              final v = _tapValue(u / 0.65);
                              align = path[k];
                              liftY = -v * 16;
                              scale = 1.0 - v * 0.08;
                            } else {
                              final move = Curves.easeInOut.transform(
                                (u - 0.65) / 0.35,
                              );
                              align = Alignment.lerp(path[k], next, move)!;
                            }
                          } else if (_isSequence) {
                            double pulse(double a, double b) => (t < a || t > b)
                                ? 0.0
                                : _tapValue((t - a) / (b - a));
                          } else if (!_isDrag) {
                            final v = _tapValue(t);
                            liftY = -v * 16;
                            scale = 1.0 - v * 0.08;
                          } else {
                            final move = _dragProgress(t);

                            final path = widget.handPath;
                            align = (path != null && path.length >= 2)
                                ? _alongPath(path, move)
                                : Alignment.lerp(
                                    widget.handAlignment,
                                    widget.handEndAlignment ??
                                        widget.handAlignment,
                                    move,
                                  )!;
                            final press = t < 0.15
                                ? t / 0.15
                                : (t < 0.8
                                      ? 1.0
                                      : 1.0 -
                                            ((t - 0.8) / 0.1).clamp(0.0, 1.0));
                            scale = 1.0 - press * 0.1;
                          }

                          return Align(
                            alignment: align,
                            child: SizedBox.shrink(
                              child: OverflowBox(
                                maxWidth: 60,
                                maxHeight: 60,
                                child: FractionalTranslation(
                                  translation: widget.handOffset,
                                  child: Transform.translate(
                                    offset: Offset(0, liftY),
                                    child: Transform.scale(
                                      scale: scale,
                                      child: child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Image.asset(
                          HowToPlayOverlay._handAsset,
                          width: 60,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
