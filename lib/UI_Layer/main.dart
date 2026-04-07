import 'package:flutter/material.dart';
import 'package:starsight/UI_Layer/signup_signin.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;

  // Star pop + wiggle
  late final AnimationController _starPopController;
  late final Animation<double> _starScale;

  late final AnimationController _wiggleController;
  late final Animation<double> _wiggle;

  // Star fly to bunny
  late final AnimationController _flyController;
  late Animation<Offset> _flyOffset;
  late final Animation<double> _starFade;

  //loading bar
  late final AnimationController _loadingController;
  late final Animation<double> _loadingAnimation;

  // Bunny
  late final AnimationController _bunnyController;
  late final Animation<double> _bunnyFade;

  // Track star visibility
  bool _showStar = false;
  bool _showBunny = false;

  // GlobalKey to find the star's position on screen
  final GlobalKey _starKey = GlobalKey();
  final GlobalKey _bunnyKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _starPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _starScale = CurvedAnimation(
      parent: _starPopController,
      curve: Curves.elasticOut,
    );

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _wiggle = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flyOffset = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero, // updated dynamically before flying
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeInOut));
    _starFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flyController, curve: const Interval(0.7, 1.0)),
    );

    _bunnyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bunnyFade = CurvedAnimation(
      parent: _bunnyController,
      curve: Curves.easeIn,
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Logo pops in
    await Future.delayed(const Duration(milliseconds: 300));
    await _logoController.forward();

    // 2. Star pops in on the "i"
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => _showStar = true);
    await _starPopController.forward();

    // 3. Star wiggles (repeat back and forth a few times)
    for (int i = 0; i < 4; i++) {
      await _wiggleController.forward();
      await _wiggleController.reverse();
    }

    // 4. Calculate fly target (center of where bunny will appear)
    final RenderBox? starBox =
        _starKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    // Target the left edge of the loading bar (where bunny starts)
    final barLeft = screenSize.width * 0.10; // matches 80% width bar centered
    final barTarget = Offset(barLeft + 40, screenSize.height * 0.68);

    if (starBox != null) {
      final starPos = starBox.localToGlobal(
        Offset(starBox.size.width / 2, starBox.size.height / 2),
      );
      (_flyOffset as dynamic); // just to reference it
      final newFlyOffset = barTarget - starPos;

      // Re-initialize fly offset with correct target
      _flyController.reset();
      final tween = Tween<Offset>(begin: Offset.zero, end: newFlyOffset);
      _flyOffset = tween.animate(
        CurvedAnimation(parent: _flyController, curve: Curves.easeInOut),
      );
    }

    setState(() {});
    await _flyController.forward();

    // Rebuild with updated fly target
    setState(() {});

    // 5. Star flies to bunny
    await _flyController.forward();

    // 6. Bunny fades in + loading bar starts
    setState(() => _showBunny = true);
    await _bunnyController.forward();
    await _loadingController.forward(); // loading bar fills up

    // 7. Navigate (after loading completes)
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const SignUpSignInScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _starPopController.dispose();
    _wiggleController.dispose();
    _flyController.dispose();
    _bunnyController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7EB),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                // Logo + star layered together
                SizedBox(
                  width: screenWidth * 0.85,
                  height: screenHeight * 0.22,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Logo (without star)
                      ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/images/splashScreen/starsight.png',
                          width: 380,
                          fit: BoxFit.fitWidth,
                        ),
                      ),

                      // Star sitting on the "i" — adjust top/left to match your logo
                      if (_showStar)
                        Positioned(
                          top: screenHeight * 0.055,
                          left: screenWidth * 0.48,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _wiggleController,
                              _flyController,
                            ]),
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _starFade,
                                child: Transform.translate(
                                  offset:
                                      _flyController.isAnimating ||
                                          _flyController.isCompleted
                                      ? _flyOffset.value
                                      : Offset.zero,
                                  child: Transform.rotate(
                                    angle:
                                        _flyController.isAnimating ||
                                            _flyController.isCompleted
                                        ? 0
                                        : _wiggle.value,
                                    child: ScaleTransition(
                                      scale: _starScale,
                                      child: Image.asset(
                                        'assets/images/splashScreen/star.png',
                                        key: _starKey,
                                        width: 44, // ← match your star size
                                        height: 39,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Bunny fades in where star flew to
                FadeTransition(
                  opacity: _bunnyFade,
                  child: _showBunny
                      ? Column(
                          children: [
                            // Loading bar
                            SizedBox(
                              width: screenWidth * 0.80,
                              height: screenHeight * 0.18,
                              child: AnimatedBuilder(
                                animation: _loadingAnimation,
                                builder: (context, child) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Background track
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8DFC8),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Fill
                                      Align(
                                        alignment: Alignment.bottomLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: _loadingAnimation.value,
                                          child: Container(
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFA726),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Bunny
                                      Positioned(
                                        left:
                                            (_loadingAnimation.value *
                                                screenWidth *
                                                0.70) -
                                            65,
                                        bottom: -30,
                                        child: Image.asset(
                                          'assets/images/splashScreen/bunnyStar.png',
                                          key: _bunnyKey,
                                          width: 160,
                                          height: 160,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(width: 200, height: 200),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
