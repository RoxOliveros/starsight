import 'package:StarSight/ui_layer/child_nickname.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import '../business_layer/parent_age_verification_business_layer.dart';
import 'app_dialog.dart';
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

class ParentAgeVerification extends StatefulWidget {
  const ParentAgeVerification({super.key});

  @override
  State<ParentAgeVerification> createState() => _ParentAgeVerificationState();
}

class _ParentAgeVerificationState extends State<ParentAgeVerification> {
  final List<String> _digits = [];
  static const int _maxDigits = 4;

  void _onDigitTap(String digit) {
    if (_digits.length < _maxDigits) {
      setState(() => _digits.add(digit));
    }
  }

  void _onDelete() {
    if (_digits.isNotEmpty) {
      setState(() => _digits.removeLast());
    }
  }

  void _onComplete() {
    final year = ParentAgeController.parseYear(_digits);
    if (year == null) return;

    if (ParentAgeController.isAdult(year)) {
      //TODO: save parent age @Ron (though I'm not sure if need pa natin nitong info nila?)
      setState(() => _digits.clear());
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) => ChildNickname(),
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
    } else {
      AppDialog.showError(context, message: "Should be Legal Age");
      return;
    }
  }

  Widget _buildDigitSlot(int index) {
    final filled = index < _digits.length;
    return Container(
      width: 36,
      height: 40,
      alignment: Alignment.center,
      child: filled
          ? Text(
              _digits[index],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: Fonts.fredoka,
                color: ColorTheme.warmBrown,
              ),
            )
          : Container(
              width: 28,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ColorTheme.warmBrown, width: 2),
                ),
              ),
              height: 32,
            ),
    );
  }

  Widget _buildKey(String label) {
    final isDelete = label == '⌫';
    return GestureDetector(
      onTap: isDelete ? _onDelete : () => _onDigitTap(label),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: ColorTheme.goldenYellow,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFc8a84b),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isDelete
            ? const Icon(
                Icons.backspace_rounded,
                color: ColorTheme.warmBrown,
                size: 22,
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontFamily: Fonts.fredoka,
                  fontWeight: FontWeight.bold,
                  color: ColorTheme.warmBrown,
                ),
              ),
      ),
    );
  }

  Widget _buildNextButton() {
    final bool isReady = _digits.length == _maxDigits;
    return GestureDetector(
      onTap: isReady ? _onComplete : null,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: isReady
              ? ColorTheme.goldenYellow
              : ColorTheme.goldenYellow.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isReady
              ? const [
                  BoxShadow(
                    color: Color(0xFFc8a84b),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_forward_rounded,
          color: isReady
              ? ColorTheme.warmBrown
              : ColorTheme.warmBrown.withValues(alpha: 0.4),
          size: 26,
        ),
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
          // Top-right cloud
          Positioned(
            top: screenHeight * 0.04,
            right: -100,
            child: Image.asset(
              'assets/gifs/night_cloud_fluffy.gif',
              width: screenWidth * 0.65,
              opacity: const AlwaysStoppedAnimation(0.85),
            ),
          ),
          // Bottom-left cloud
          Positioned(
            bottom: screenHeight * -0.09,
            left: -130,
            child: Image.asset(
              'assets/gifs/night_cloud.gif',
              width: screenWidth * 0.80,
              opacity: const AlwaysStoppedAnimation(0.85),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: back button + progress bar ──
                AppTopBar(progress: 0.25),

                // ── Rest of your screen ──
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: screenHeight * 0.1),

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
                                  child: Image.asset(
                                    'assets/gifs/dancing_dog.gif',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'Parents, please enter your birth year to confirm your age',
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

                        const SizedBox(height: 20),

                        // Input display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 100),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTheme.cream.withValues(alpha: 0.39),
                              border: Border.all(color: ColorTheme.warmBrown),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                _maxDigits,
                                (i) => _buildDigitSlot(i),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Numpad
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['1', '2', '3'].map(_buildKey).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['4', '5', '6'].map(_buildKey).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['7', '8', '9'].map(_buildKey).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNextButton(),
                                _buildKey('0'),
                                _buildKey('⌫'),
                              ],
                            ),
                          ],
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
