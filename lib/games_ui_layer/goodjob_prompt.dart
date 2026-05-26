import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// SAMPLE
// Widget _buildGoodJobOverlay() {
//   return GoodJobOverlay(
//     characterImage: CHARACTERPATH <-- CHANGE THIS,
//     closeButtonColor: const Color(BUTTONCOLOR <-- CHANGE THIS),
//     // or your arctic blue
//     onNext: () {
//       // Navigator.of(context).pushReplacement(
//       //   MaterialPageRoute(builder: (_) => const NextLevelScreen() <-- CHANGE THIS),
//       // );
//     },
//     onRestart: () {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (_) => const GameScreen()<-- CHANGE THIS),
//         );
//       },
//     onBack: () {
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (_) => const LevelScreen() <-- CHANGE THIS),
//             (route) => false,
//       );
//     },
//   );
// }

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
    await _audioPlayer.play(AssetSource('audio/yey.wav'));
  }

  @override
  Widget build(BuildContext context) {
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
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ScaleTransition(
                    scale: _bannerScale,
                    child: const _ArcedGoodJobBanner(),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _charBounceCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _charBounce.value),
                    child: child,
                  ),
                  child: ScaleTransition(
                    scale: _charScale,
                    child: _buildCharacter(),
                  ),
                ),
              ),
            ),

            // ── Restart button — bottom left ──────────────────────────
            Positioned(
              bottom: 28,
              left: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/restart.png',
                onTap: widget.onRestart,
                size: 88,
                tooltip: 'Restart',
              ),
            ),

            // ── Next button — bottom right ────────────────────────────
            Positioned(
              bottom: 28,
              right: 32,
              child: _ImageButton(
                imagePath: 'assets/images/buttons/next.png',
                onTap: widget.onNext,
                size: 88,
                tooltip: 'Next Level',
              ),
            ),

            // ── X (Back) button — top left ────────────────────────────
            Positioned(
              top: 16,
              left: 16,
              child: _CloseButton(
                onTap: widget.onBack,
                color: widget.closeButtonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return Image.asset(
      widget.characterImage,
      height: 400,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.pets, size: 120, color: Colors.white),
    );
  }
}

// ── Arced "GOOD JOB!" banner ──────────────────────────────────────────────────

// WITH this:
class _ArcedGoodJobBanner extends StatelessWidget {
  const _ArcedGoodJobBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/goodjob.png',
      width: 800,
      fit: BoxFit.contain,
    );
  }
}

// ── X close/back button ───────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _CloseButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
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
