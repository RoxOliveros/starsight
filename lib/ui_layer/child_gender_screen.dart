import 'package:StarSight/ui_layer/parents_pin_setup.dart'; // <-- Navigates here next
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

class ChildGenderScreen extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;
  final String childBirthdate;

  const ChildGenderScreen({
    super.key,
    required this.nickname,
    required this.parentBirthYear,
    required this.childBirthdate,
  });

  @override
  State<ChildGenderScreen> createState() => _ChildGenderScreenState();
}

class _ChildGenderScreenState extends State<ChildGenderScreen> {
  String? _selectedGender;
  final List<String> _genders = ['Boy', 'Girl'];

  void _onNext() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ParentPinVerification(
              nickname: widget.nickname,
              childBirthdate: widget.childBirthdate,
              childGender: _selectedGender!,
              parentBirthYear: widget.parentBirthYear,
            ),
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
    final bool isReady = _selectedGender != null;

    return Scaffold(
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          Positioned(
            bottom: screenHeight * 0.12,
            left: -80,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.65,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTopBar(progress: 0.75), // Adjusted progress

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
                          "What is ${widget.nickname}'s gender?",
                          style: const TextStyle(
                            color: ColorTheme.cream,
                            fontSize: 18,
                            fontFamily: Fonts.fredoka,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gender",
                        style: TextStyle(
                          color: ColorTheme.cream,
                          fontSize: 16,
                          fontFamily: Fonts.fredoka,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: _genders.map((gender) {
                          final isSelected = _selectedGender == gender;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGender = gender;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ColorTheme.goldenYellow.withValues(
                                          alpha: 0.35,
                                        )
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: isSelected
                                        ? ColorTheme.goldenYellow
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: isSelected
                                          ? ColorTheme.goldenYellow
                                          : ColorTheme.goldenYellow.withValues(
                                              alpha: 0.6,
                                            ),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      gender,
                                      style: TextStyle(
                                        fontFamily: Fonts.fredoka,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? ColorTheme.cream
                                            : ColorTheme.cream.withValues(
                                                alpha: 0.75,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isReady ? _onNext : null,
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
                              'NEXT',
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
                              color: ColorTheme.cream,
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
