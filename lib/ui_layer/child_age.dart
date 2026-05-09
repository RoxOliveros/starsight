import 'package:StarSight/ui_layer/child_goal.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'appbar_signup.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color darkBlue = Color(0xFF5F7199);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class ChildAge extends StatefulWidget {
  final String nickname;

  const ChildAge({super.key, required this.nickname});

  @override
  State<ChildAge> createState() => _ChildAgeState();
}

class _ChildAgeState extends State<ChildAge> with TickerProviderStateMixin {
  int? _selectedIndex;

  final List<String> _ageLabels = [
    '0-1\nyears old',
    '1-2\nyears old',
    '2-3\nyears old',
    '4 years\nold above',
  ];

  final List<List<double>> _positions = [
    [0.25, 0.25], // top-left
    [0.75, 0.35], // top-right
    [0.22, 0.50], // bottom-left
    [0.72, 0.60], // bottom-right
  ];

  final List<double> _angles = [-0.15, 0.1, 0.05, -0.08];

  late List<AnimationController> _bounceControllers;
  late List<Animation<double>> _bounceAnimations;

  @override
  void initState() {
    super.initState();
    _bounceControllers = List.generate(_ageLabels.length, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      return controller;
    });

    _bounceAnimations = _bounceControllers.map((c) {
      return Tween<double>(
        begin: 1.0,
        end: 1.12,
      ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut));
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _bounceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStarTap(int index) {
    if (_selectedIndex != null && _selectedIndex != index) {
      _bounceControllers[_selectedIndex!].reverse();
    }

    setState(() => _selectedIndex = index);
    _bounceControllers[index].forward(from: 0);
  }

  void _onNext() {
    final selectedAge = _ageLabels[_selectedIndex!].replaceAll('\n', ' ');
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChildGoal(nickname: widget.nickname, age: selectedAge),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          // Clouds
          Positioned(
            top: screenHeight * 0.35,
            left: -120,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.55,
              fit: BoxFit.contain,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
          Positioned(
            top: screenHeight * 0.50,
            right: -100,
            child: Lottie.asset(
              'assets/animations/night_cloud_fluffy.json',
              width: screenWidth * 0.60,
              fit: BoxFit.contain,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.10,
            left: -70,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.65,
              fit: BoxFit.contain,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),

          // Stars
          ...List.generate(_ageLabels.length, (i) {
            final isSelected = _selectedIndex == i;
            final double starFraction = 0.43;
            final size = screenWidth * starFraction;

            final rawLeft = (_positions[i][0] * screenWidth) - (size / 2);
            final left = rawLeft.clamp(8.0, screenWidth - size - 8.0);
            final top = _positions[i][1] * screenHeight;

            return Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                onTap: () => _onStarTap(i),
                child: ScaleTransition(
                  scale: _bounceAnimations[i],
                  child: Transform.rotate(
                    angle: _angles[i],
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Star image — vibrant when selected, desaturated when not
                        ColorFiltered(
                          colorFilter: isSelected
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.saturation,
                                )
                              : const ColorFilter.matrix([
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0.2126,
                                  0.7152,
                                  0.0722,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  1,
                                  0,
                                ]),
                          child: Image.asset(
                            'assets/images/star.png',
                            width: size,
                            height: size,
                          ),
                        ),
                        // Label
                        Text(
                          _ageLabels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: Fonts.fredoka,
                            fontSize: size * 0.085,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? ColorTheme.warmBrown
                                : ColorTheme.warmBrown.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Foreground UI
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTopBar(progress: 0.75),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 120,
                        child: OverflowBox(
                          maxWidth: 140,
                          child: Lottie.asset(
                            'assets/animations/dancing_dog.json',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'How old is ${widget.nickname}?',
                          style: const TextStyle(
                            color: Color(0xFFFAF7EB),
                            fontSize: 20,
                            fontFamily: Fonts.fredoka,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom next and sign in link
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedIndex != null ? _onNext : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorTheme.goldenYellow,
                              disabledBackgroundColor: ColorTheme.goldenYellow
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0xFF3A4F6E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontFamily: Fonts.fredoka,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ColorTheme.warmBrown,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInAccount(),
                            ),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Color(0xFFFAF7EB),
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: 'Have an account? ',
                                style: TextStyle(fontFamily: Fonts.fredoka),
                              ),
                              TextSpan(
                                text: 'Sign in here!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: Fonts.fredoka,
                                  decoration: TextDecoration.underline,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
