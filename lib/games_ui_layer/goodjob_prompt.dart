import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class GoodJobOverlay extends StatefulWidget {
  final String characterImage;
  final Color closeButtonColor;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const GoodJobOverlay({
    super.key,
    required this.characterImage,
    required this.closeButtonColor,
    required this.onNext,
    required this.onRestart,
    required this.onBack,
  });

  @override
  State<GoodJobOverlay> createState() => _GoodJobOverlayState();
}

class _GoodJobOverlayState extends State<GoodJobOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late AnimationController _starsCtrl;
  late AnimationController _charBounceCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _bannerScale;
  late Animation<double> _charScale;
  late Animation<double> _charBounce;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _initAudio();
    _playYeySound();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _charBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeIn);

    _bannerScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 20),
    ]).animate(_entranceCtrl);

    _charScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(_entranceCtrl);

    _charBounce = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _charBounceCtrl, curve: Curves.easeInOut),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _starsCtrl.dispose();
    _charBounceCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playYeySound() async {
    await _audioPlayer.play(AssetSource('audio/sound_effects/yey.wav'));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fall back to MediaQuery if this widget is given unbounded/loose
        // constraints (e.g. wrapped in a Stack without explicit size).
        final mq = MediaQuery.of(context).size;
        final double screenWidth =
        constraints.maxWidth.isFinite ? constraints.maxWidth : mq.width;
        final double screenHeight =
        constraints.maxHeight.isFinite ? constraints.maxHeight : mq.height;

        // Use the shorter side so layout stays sane in both portrait and
        // landscape, and on tablets/desktop as well as phones.
        final double shortestSide =
        screenWidth < screenHeight ? screenWidth : screenHeight;

        // Reference: a 390pt-wide phone is "1.0" scale. Clamp so things
        // don't get comically small on tiny screens or huge on tablets.
        final double scale = (shortestSide / 390).clamp(0.7, 1.6);

        // ── Responsive metrics ────────────────────────────────────────
        final double bannerWidth =
        (550 * scale).clamp(220.0, screenWidth * 0.9);
        final double bannerTop =
        (screenHeight * 0.06).clamp(24.0, 70.0);

        final double characterHeight =
        (350 * scale);
        final double characterTop =
        (screenHeight * 0.17).clamp(90.0, 190.0);

        final double actionButtonSize =
        (88 * scale).clamp(56.0, 120.0);
        final double edgeMargin =
        (screenWidth * 0.08).clamp(16.0, 48.0);
        final double bottomMargin =
        (screenHeight * 0.035).clamp(16.0, 44.0);

        final double closeButtonSize =
        (48 * scale).clamp(38.0, 58.0);
        final double closeButtonInset =
        (12 * scale).clamp(10.0, 22.0);

        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            // Semi-transparent dark overlay so game background shows through
            color: Colors.black.withValues(alpha: 0.45),
            child: Stack(
              children: [
                Positioned(
                  top: bannerTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8 * scale),
                      child: ScaleTransition(
                        scale: _bannerScale,
                        child: _ArcedGoodJobBanner(width: bannerWidth),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: characterTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _charBounceCtrl,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _charBounce.value * scale),
                        child: child,
                      ),
                      child: ScaleTransition(
                        scale: _charScale,
                        child: _buildCharacter(characterHeight),
                      ),
                    ),
                  ),
                ),

                // ── Restart button — bottom left ──────────────────────
                Positioned(
                  bottom: bottomMargin,
                  left: edgeMargin,
                  child: _ImageButton(
                    imagePath: 'assets/images/buttons/restart.png',
                    onTap: widget.onRestart,
                    size: actionButtonSize,
                    tooltip: 'Restart',
                  ),
                ),

                // ── Next button — bottom right ────────────────────────
                Positioned(
                  bottom: bottomMargin,
                  right: edgeMargin,
                  child: _ImageButton(
                    imagePath: 'assets/images/buttons/next.png',
                    onTap: widget.onNext,
                    size: actionButtonSize,
                    tooltip: 'Next Level',
                  ),
                ),

                // ── X (Back) button — top left ────────────────────────
                Positioned(
                  top: closeButtonInset,
                  left: closeButtonInset,
                  child: _CloseButton(
                    onTap: widget.onBack,
                    color: widget.closeButtonColor,
                    size: closeButtonSize,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacter(double height) {
    return Image.asset(
      widget.characterImage,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.pets, size: height * 0.4, color: Colors.white),
    );
  }
}

// ── Arced "GOOD JOB!" banner ──────────────────────────────────────────────────

class _ArcedGoodJobBanner extends StatelessWidget {
  final double width;

  const _ArcedGoodJobBanner({required this.width});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/goodjob.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}

// ── X close/back button ───────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _CloseButton({
    required this.onTap,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: size * 0.17,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Icon(
          Icons.close_rounded,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

// ── Image button (Restart / Next) ─────────────────────────────────────────────

class _ImageButton extends StatefulWidget {
  final String imagePath;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _ImageButton({
    required this.imagePath,
    required this.onTap,
    required this.size,
    required this.tooltip,
  });

  @override
  State<_ImageButton> createState() => _ImageButtonState();
}

class _ImageButtonState extends State<_ImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(
          scale: _ctrl,
          child: Image.asset(
            widget.imagePath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.circle, size: widget.size, color: Colors.orange),
          ),
        ),
      ),
    );
  }
}