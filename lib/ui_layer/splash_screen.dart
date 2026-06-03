import 'package:StarSight/UI_Layer/signup_signin.dart';
import 'package:StarSight/business_layer/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/dashboard.dart';

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

  // Loading bar
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
      end: Offset.zero,
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
    if (!mounted) return;
    final screenSize = MediaQuery.of(context).size;

    // Show the bunny/bar early (invisible) so the key is mounted
    setState(() => _showBunny = true);
    await Future.delayed(const Duration(milliseconds: 50));

    final RenderBox? barBox =
        _loadingBarKey.currentContext?.findRenderObject() as RenderBox?;
    final barTarget = barBox != null
        ? barBox.localToGlobal(Offset(0, barBox.size.height / 2))
        : Offset(screenSize.width * 0.12, screenSize.height * 0.62);

    setState(() => _showBunny = false);

    if (starBox != null) {
      final starPos = starBox.localToGlobal(
        Offset(starBox.size.width / 2, starBox.size.height / 2),
      );
      final newFlyOffset = barTarget - starPos;

      _flyController.reset();
      final tween = Tween<Offset>(begin: Offset.zero, end: newFlyOffset);
      _flyOffset = tween.animate(
        CurvedAnimation(parent: _flyController, curve: Curves.easeInOut),
      );
    }

    setState(() {});

    // 5. Star flies to bunny
    await _flyController.forward();

    // 6. Bunny fades in and loading bar runs
    setState(() => _showBunny = true);
    await _bunnyController.forward();

    // Wait for the loading bar to finish reaching 100%
    await _loadingController.forward();

    // --- UPDATED LOGIC: Auth Check + Database Safety Check ---
    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          // THEY ARE LOGGED IN -> Let's make sure their DB data still exists!
          String fetchedNickname = await DatabaseService().getNickname();

          if (fetchedNickname.isNotEmpty) {
            // DB exists! Go to Dashboard.
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, __, ___) =>
                    DashboardScreen(nickname: fetchedNickname),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          } else {
            // DB is empty/deleted! Force a logout.
            throw Exception("Database profile missing.");
          }
        } catch (e) {
          // If the DB was deleted or corrupted, forcefully sign them out
          await FirebaseAuth.instance.signOut();

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (_, __, ___) => const SignUpSignInScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      } else {
        // THEY ARE NOT LOGGED IN -> Go to Start Screen
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
                SizedBox(height: screenHeight * 0.18),

                // Logo + star layered together
                SizedBox(
                  width: screenWidth * 0.75,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final logoW = constraints.maxWidth;
                      final logoH = logoW / (1500 / 805);

                      final starX = logoW * 0.63;
                      final starY = logoH * 0.45;

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
                              top: starY - 19,
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
                                            'assets/images/icons/logo_star.png',
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
                                            left:
                                                -bunnyWidth * 0.35 +
                                                _loadingAnimation.value *
                                                    (barWidth -
                                                        bunnyWidth +
                                                        bunnyWidth * 0.35),
                                            bottom: -bunnyHeight * 0.20,
                                            child: Image.asset(
                                              'assets/images/characters/bunny_riding_star.png',
                                              key: _bunnyKey,
                                              height: screenHeight * 0.15,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
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
