import 'package:flutter/material.dart';

class HowToPlayOverlay extends StatefulWidget {
  final Widget previewChild;
  final Alignment handAlignment;
  final Alignment? handEndAlignment;
  final Offset handOffset;
  final VoidCallback? onDismiss;
  final bool tapSequence;

  const HowToPlayOverlay({
    super.key,
    required this.previewChild,
    required this.handAlignment,
    this.handEndAlignment,
    this.handOffset = Offset.zero,
    this.onDismiss,
    this.tapSequence = false,
  });

  static const String _handAsset = 'assets/images/objects/lagoon/pointing_hand.png';

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl;

  bool get _isSequence => widget.tapSequence && widget.handEndAlignment != null;
  bool get _isDrag => widget.handEndAlignment != null && !widget.tapSequence;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _isDrag ? 2200 : (_isSequence ? 2600 : 900)),
    )..repeat();
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  // 0 -> 1 -> 0 pulse used by tap mode
  double _tapValue(double t) {
    if (t < 0.4) return Curves.easeOut.transform(t / 0.4);
    if (t < 0.6) return 1.0;
    return 1.0 - Curves.easeIn.transform((t - 0.6) / 0.4);
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
                            child: widget.previewChild,
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _tapCtrl,
                      builder: (_, child) {
                        final t = _tapCtrl.value;
                        var align = widget.handAlignment;
                        var liftY = 0.0;
                        var scale = 1.0;

                        if (_isSequence) {
                          double pulse(double a, double b) =>
                              (t < a || t > b) ? 0.0 : _tapValue((t - a) / (b - a));

                          final p = pulse(0.0, 0.25) + pulse(0.5, 0.75);
                          final toEnd =
                          Curves.easeInOut.transform(((t - 0.25) / 0.25).clamp(0.0, 1.0));
                          final back =
                          Curves.easeInOut.transform(((t - 0.8) / 0.2).clamp(0.0, 1.0));

                          align = Alignment.lerp(
                              widget.handAlignment, widget.handEndAlignment!, toEnd - back)!;
                          liftY = -p * 16;
                          scale = 1.0 - p * 0.08;
                        } else if (!_isDrag) {
                          final v = _tapValue(t);
                          liftY = -v * 16;
                          scale = 1.0 - v * 0.08;
                        } else {
                          final move = Curves.easeInOut
                              .transform(((t - 0.2) / 0.55).clamp(0.0, 1.0));
                          align = Alignment.lerp(
                              widget.handAlignment, widget.handEndAlignment!, move)!;
                          final press = t < 0.15
                              ? t / 0.15
                              : (t < 0.8
                              ? 1.0
                              : 1.0 - ((t - 0.8) / 0.1).clamp(0.0, 1.0));
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
                                  child: Transform.scale(scale: scale, child: child),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Image.asset(HowToPlayOverlay._handAsset, width: 60),
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