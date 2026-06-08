import 'dart:async';
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/orientation_service.dart';
import 'parent_age_verification.dart';
import 'password_reset_screen.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';

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

  bool _animationsReady = false;

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  static bool _hasHandledInitialLink = false;
  String? _lastHandledCode;
  @override
  void initState() {
    super.initState();
    OrientationService.setPortrait();
    _loadAnimations();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // --- START LISTENING FOR LINKS ---
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // Catch the link if the app is currently running in the background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    });

    // Catch the link if the app was completely closed, BUT ONLY ONCE!
    if (!_hasHandledInitialLink) {
      _hasHandledInitialLink =
          true; // Mark it as handled so we never read it again!

      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    }
  }

  void _handleLink(Uri uri) {
    print("Deep link received: $uri");
    if (uri.queryParameters['mode'] == 'resetPassword') {
      final String? oobCode = uri.queryParameters['oobCode'];
      print("oobCode: $oobCode");

      if (oobCode == null || oobCode == _lastHandledCode) return;

      _lastHandledCode = oobCode;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordResetScreen(oobCode: oobCode),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _linkSubscription?.cancel(); // Close the listener
    super.dispose();
  }

  Future<void> _loadAnimations() async {
    await Future.wait([
      AssetLottie('assets/animations/white_clouds.json').load(),
      AssetLottie('assets/animations/peeking_penguin.json').load(),
    ]);
    if (mounted) {
      setState(() => _animationsReady = true);
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: _animationsReady
            ? FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    //cloud
                    Flexible(
                      flex: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Lottie.asset(
                          'assets/animations/white_clouds.json',
                          fit: BoxFit.fitWidth,
                          frameRate: FrameRate(30),
                          frameBuilder: (context, child, composition) {
                            if (composition == null) {
                              return const SizedBox.shrink();
                            }
                            return child;
                          },
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignInAccount(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),

                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: AppTextStyles.body,
                                children: [
                                  TextSpan(
                                    text: 'By continuing, you agree to our ',
                                  ),
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
                        child: Lottie.asset(
                          'assets/animations/peeking_penguin.json',
                          fit: BoxFit.fitWidth,
                          frameRate: FrameRate(30),
                          frameBuilder: (context, child, composition) {
                            if (composition == null) {
                              return const SizedBox.shrink();
                            }
                            return child;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Image.asset(
                  'assets/images/characters/doma_writing_on_board.png',
                  width: 250,
                  height: 250,
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
