import 'package:flutter/material.dart';
import 'package:starsight/signup_signin.dart';

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
  late final Animation<Offset> _flyOffset;
  late final Animation<double> _starFade;

  // Bunny
  late final AnimationController _bunnyController;
  late final Animation<double> _bunnyFade;

  // Track star visibility
  bool _showStar = false;
  bool _showBunny = false;

  // GlobalKey to find the star's position on screen
  final GlobalKey _starKey = GlobalKey();
  Offset _flyTarget = Offset.zero; // where the star flies to (bunny center)

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
      CurvedAnimation(
        parent: _flyController,
        curve: const Interval(0.7, 1.0),
      ),
    );

    _bunnyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bunnyFade = CurvedAnimation(
      parent: _bunnyController,
      curve: Curves.easeIn,
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
    // Bunny will be centered at ~65% down the screen
    final bunnyCenter = Offset(screenSize.width / 2, screenSize.height * 0.65);

    if (starBox != null) {
      final starPos = starBox.localToGlobal(
        Offset(starBox.size.width / 2, starBox.size.height / 2),
      );
      _flyTarget = bunnyCenter - starPos;
    }

    // Rebuild with updated fly target
    setState(() {});

    // 5. Star flies to bunny
    await _flyController.forward();

    // 6. Bunny fades in
    setState(() => _showBunny = true);
    await _bunnyController.forward();

    // 7. Navigate
    await Future.delayed(const Duration(milliseconds: 800));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7EB),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo + star layered together
                SizedBox(
                  width: 260,
                  height: 160,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Logo (without star)
                      ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/images/splashScreen/starsight.png',
                          width: 600,
                        ),
                      ),

                      // Star sitting on the "i" — adjust top/left to match your logo
                      if (_showStar)
                        Positioned(
                          top: 10,   // ← adjust to sit on the "i"
                          left: 118, // ← adjust to sit on the "i"
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _wiggleController,
                              _flyController,
                            ]),
                            builder: (context, child) {
                              return FadeTransition(
                                opacity: _starFade,
                                child: Transform.translate(
                                  offset: _flyController.isAnimating ||
                                      _flyController.isCompleted
                                      ? _flyOffset.value
                                      : Offset.zero,
                                  child: Transform.rotate(
                                    angle: _flyController.isAnimating ||
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
                      ? Image.asset(
                    'assets/images/splashScreen/bunnyStar.png',
                    width: 200,
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