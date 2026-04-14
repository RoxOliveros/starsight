import 'package:flutter/material.dart';
import 'parent_age_verification.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
  static const String poppins = 'Poppins-Regular';

  static const TextStyle heading = TextStyle(
    fontFamily: fredoka,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: ColorTheme.deepNavyBlue,
  );

  static const TextStyle subHeading = TextStyle(
    fontFamily: fredoka,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: ColorTheme.deepNavyBlue,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fredoka,
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fredoka,
    fontSize: 12,
    color: ColorTheme.orange,
  );

  static const TextStyle bodylink = TextStyle(
    fontFamily: fredoka,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: ColorTheme.orange,
  );
}

abstract class AppDimensions {
  static const double screenPadding = 28.0;
  static const double buttonHeight = 52.0;
  static const double buttonRadius = 30.0;
  static const double cardRadius = 28.0;
}

class SignUpSignInScreen extends StatefulWidget {
  const SignUpSignInScreen({super.key});

  @override
  State<SignUpSignInScreen> createState() => _SignUpSignInScreenState();
}

class _SignUpSignInScreenState extends State<SignUpSignInScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              //cloud
              Flexible(
                flex: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    'assets/gifs/white_cloud.gif',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Start Your\nChild's Journey",
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      "Track your child's progress while they play\nand learn with us!",
                      style: AppTextStyles.subHeading,
                    ),
                    const SizedBox(height: 36),

                    _PrimaryButton(
                      label: 'SIGN UP',
                      backgroundColor: ColorTheme.deepNavyBlue,
                      textColor: ColorTheme.cream,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ParentAgeVerification(),
                            ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    _OutlineButton(
                      label: 'SIGN IN',
                      textColor: ColorTheme.deepNavyBlue,
                      borderColor: ColorTheme.deepNavyBlue,
                      onTap: () {
                        // TODO: navigate to signin
                      },
                    ),
                    const SizedBox(height: 18),

                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: AppTextStyles.body,
                          children: [
                            TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms and\nConditions',
                              style: AppTextStyles.bodylink,
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTextStyles.bodylink,
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              //penguin
              Flexible(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/gifs/peeking_penguin.gif',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//button
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 3,
          shadowColor: backgroundColor.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonLabel.copyWith(color: textColor),
        ),
      ),
    );
  }
}

//button outline
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.textColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonLabel.copyWith(color: textColor),
        ),
      ),
    );
  }
}
