import 'package:StarSight/ui_layer/parents_pin_setup.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../games_ui_layer/audio_helper.dart';
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
      resizeToAvoidBottomInset: false,
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          Positioned(
            top: screenHeight * 0.65,
            right: -130,
            child: Lottie.asset(
              'assets/animations/night_cloud_fluffy.json',
              width: screenWidth * 0.80,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
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
                AppTopBar(progress: 0.75), // Adjusted progress

            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.04),
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

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _genders.reversed.map((gender) {
                          final isSelected = _selectedGender == gender;
                          final String imagePath = gender == 'Boy'
                              ? 'assets/images/boy.png'
                              : 'assets/images/girl.png';
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: gender == 'Boy' ? 8 : 0,
                                right: gender == 'Girl' ? 8 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  SfxHelper.instance.play(Sfx.keyTap);
                                  setState(() => _selectedGender = gender);
                                },
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 150,
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? ColorTheme.goldenYellow.withValues(alpha: 0.35)
                                            : Colors.white.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: isSelected
                                              ? ColorTheme.goldenYellow
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                      child: Image.asset(imagePath, fit: BoxFit.contain),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      gender.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: Fonts.fredoka,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? ColorTheme.goldenYellow
                                            : ColorTheme.cream,
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
                            onPressed: isReady
                                ? () {
                              SfxHelper.instance.play(Sfx.keyTap);
                              _onNext();
                            }
                                : null,
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
                          SfxHelper.instance.play(Sfx.keyTap);
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
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}