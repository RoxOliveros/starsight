import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'app_dialog.dart';
import 'appbar_signup.dart';
import 'child_age.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color darkBlue = Color(0xFF5F7199);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class ChildNickname extends StatefulWidget {
  final String parentBirthYear;

  const ChildNickname({super.key, required this.parentBirthYear});

  @override
  State<ChildNickname> createState() => _ChildNickname();
}

class _ChildNickname extends State<ChildNickname> {
  final TextEditingController _nicknameController = TextEditingController();

  void _onNext() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      AppDialog.showError(context, message: "Nickname should not be empty");
      return;
    }

    if (nickname.contains(' ')) {
      AppDialog.showError(
        context,
        message: "Nickname should not contain any spaces",
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => ChildAge(
          nickname: nickname,
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
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          // Mid-right cloud
          Positioned(
            top: screenHeight * 0.65,
            right: -30,
            child: Lottie.asset(
              'assets/animations/night_cloud_fluffy.json',
              width: screenWidth * 0.65,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
          // Top-left cloud
          Positioned(
            bottom: screenHeight * 0.90,
            left: -130,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.80,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),

          // Stars
          Positioned(
            top: screenHeight * 0.70,
            left: screenWidth * 0.20,
            child: Transform.rotate(
              angle: 0.4,
              child: Image.asset('assets/images/night_star.png', width: 40),
            ),
          ),
          Positioned(
            top: screenHeight * 0.60,
            right: screenWidth * 0.35,
            child: Transform.rotate(
              angle: 0.9,
              child: Image.asset('assets/images/night_star.png', width: 50),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.02,
            left: screenWidth * 0.01,
            child: Transform.rotate(
              angle: 0.6,
              child: Image.asset('assets/images/night_star.png', width: 100),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.09,
            right: screenWidth * 0.06,
            child: Transform.rotate(
              angle: 0.3,
              child: Image.asset('assets/images/night_star.png', width: 60),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: back button + progress bar ──
                AppTopBar(progress: 0.50),

                // ── Rest of your screen ──
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: screenHeight * 0.04),

                        // Dog + message row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 150,
                                child: OverflowBox(
                                  maxWidth: 160,
                                  child: Lottie.asset(
                                    'assets/animations/dancing_dog.json',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'Who will be playing today? Enter their nickname!',
                                  // ← changed
                                  style: TextStyle(
                                    color: Color(0xFFFAF7EB),
                                    fontSize: 18,
                                    fontFamily: Fonts.fredoka,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Nickname input + Next button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: ColorTheme.cream.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: ColorTheme.cream.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _nicknameController,
                                        maxLength: 10,
                                        style: const TextStyle(
                                          color: ColorTheme.cream,
                                          fontFamily: Fonts.fredoka,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: "Child's nickname",
                                          hintStyle: TextStyle(
                                            color: ColorTheme.cream,
                                            fontFamily: Fonts.fredoka,
                                            fontSize: 14,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.never,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          counterText: '',
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: ElevatedButton(
                                        onPressed: _onNext,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ColorTheme.cream,
                                          foregroundColor: ColorTheme.darkBlue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                        ),
                                        child: const Text(
                                          'Next',
                                          style: TextStyle(
                                            fontFamily: Fonts.fredoka,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              const Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: Text(
                                  'Keep it short! Up to 10 characters and no spaces.',
                                  style: TextStyle(
                                    color: ColorTheme.cream,
                                    fontSize: 12,
                                    fontFamily: Fonts.fredoka,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Bottom sign in link
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: GestureDetector(
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
    );
  }
}
