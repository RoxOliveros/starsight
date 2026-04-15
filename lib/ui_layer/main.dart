import 'package:StarSight/UI_Layer/signup_signin.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

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
  final GlobalKey _loadingBarKey = GlobalKey();

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

    // Show the bunny/bar early (invisible) so the key is mounted
    setState(() => _showBunny = true);
    await Future.delayed(const Duration(milliseconds: 50)); // let it render

    final RenderBox? barBox =
        _loadingBarKey.currentContext?.findRenderObject() as RenderBox?;
    final barTarget = barBox != null
        ? barBox.localToGlobal(Offset(0, barBox.size.height / 2))
        : Offset(screenSize.width * 0.12, screenSize.height * 0.62); // fallback

    // Then hide it again until the star arrives:
    setState(() => _showBunny = false);

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
                SizedBox(height: screenHeight * 0.18),

                // Logo + star layered together
                SizedBox(
                  width: screenWidth * 0.75,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final logoW = constraints.maxWidth;
                      final logoH = logoW / (1500 / 805);

                      // Tune these two values to pin the star on your "i" dot
                      final starX =
                          logoW * 0.63; // 0.0 = left edge, 1.0 = right edge
                      final starY =
                          logoH * 0.45; // 0.0 = top edge, 1.0 = bottom edge

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Logo
                          Align(
                            alignment: Alignment.center,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Image.asset(
                                'assets/gifs/starsight.gif',
                                width: screenWidth * 0.75,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // Star pinned relative to logo size
                          if (_showStar)
                            Positioned(
                              left: starX - 22,
                              // 22 = half of star width (44/2)
                              top: starY - 19,
                              // 19 = half of star height (39/2)
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
                                            'assets/images/logo_star.png',
                                            key: _starKey,
                                            width: 44,
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
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Bunny fades in where star flew to
                FadeTransition(
                  opacity: _bunnyFade,
                  child: _showBunny
                      ? Column(
                          children: [
                            SizedBox(
                              width: screenWidth * 0.80,
                              height: screenHeight * 0.18 < 160
                                  ? 160
                                  : screenHeight * 0.18,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth = constraints.maxWidth;
                                  const double bunnyAspectRatio = 108 / 149;
                                  final double bunnyHeight =
                                      screenHeight * 0.20;
                                  final double bunnyWidth =
                                      bunnyHeight * bunnyAspectRatio;

                                  return AnimatedBuilder(
                                    animation: _loadingAnimation,
                                    builder: (context, child) {
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Background track
                                          Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              key: _loadingBarKey,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8DFC8),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                          // Fill
                                          Align(
                                            alignment: Alignment.bottomLeft,
                                            child: FractionallySizedBox(
                                              widthFactor:
                                                  _loadingAnimation.value,
                                              child: Container(
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFA726,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Bunny
                                          Positioned(
                                            //left: _loadingAnimation.value * (barWidth - bunnyWidth) - (bunnyWidth * 0.35),
                                            left:
                                                -bunnyWidth * 0.35 +
                                                _loadingAnimation.value *
                                                    (barWidth -
                                                        bunnyWidth +
                                                        bunnyWidth * 0.35),
                                            bottom: -bunnyHeight * 0.20,
                                            child: Image.asset(
                                              'assets/images/bunnystar.png',
                                              key: _bunnyKey,
                                              height: screenHeight * 0.20,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                      ); // Stack
                                    }, // AnimatedBuilder builder
                                  ); // AnimatedBuilder
                                }, // LayoutBuilder builder
                              ), // LayoutBuilder
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
