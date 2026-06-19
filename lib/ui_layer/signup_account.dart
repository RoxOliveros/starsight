import 'package:StarSight/business_layer/orientation_service.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/auth_service.dart';
import '../business_layer/database_service.dart';
import 'app_dialog.dart';
import 'consent_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color orange = Color(0xFFEC8A20);
  static const Color goldenYellow = Color(0xFFFBD481);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';

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

class SignUpAccount extends StatefulWidget {
  final String nickname;
  final List<String> goals;
  final String parentBirthYear;
  final String parentPin;

  const SignUpAccount({
    super.key,
    required this.nickname,
    required this.goals,
    required this.parentBirthYear,
    required this.parentPin,
  });

  @override
  State<SignUpAccount> createState() => _SignUpAccountState();
}

class _SignUpAccountState extends State<SignUpAccount>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController(); // 1. ADDED CONTROLLER
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    OrientationService.setPortrait();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignUp() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      AppDialog.showError(
        context,
        message: "Please enter a valid email address.",
      );
      return;
    }
    if (password.length < 6) {
      AppDialog.showError(
        context,
        message: "Password must be at least 6 characters.",
      );
      return;
    }

    if (password != confirmPassword) {
      AppDialog.showError(
        context,
        message: "Passwords do not match! Please try again.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? error = await AuthService().signUpWithEmail(email, password);

    if (!mounted) return;
    Navigator.pop(context);

    if (error == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().createParentAndChild(
          uid: user.uid,
          email: email,
          childNickname: widget.nickname,
          childGoals: widget.goals,
          parentBirthYear: widget.parentBirthYear,
          parentPin: widget.parentPin,
        );
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ConsentScreen()),
        (route) => false,
      );
    } else {
      AppDialog.showError(context, message: error);
    }
  }

  void _onGoogleSignUp() async {
    bool success = await AuthService().signInWithGoogle();

    if (success) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService().createParentAndChild(
          uid: user.uid,
          email: user.email ?? '',
          childNickname: widget.nickname,
          childGoals: widget.goals,
          parentBirthYear: widget.parentBirthYear,
          parentPin: widget.parentPin,
        );
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConsentScreen()),
      );
    } else {
      if (!mounted) return;
      AppDialog.showError(
        context,
        message: "Google Sign-Up was canceled or failed.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              Flexible(
                flex: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Lottie.asset(
                    'assets/animations/white_clouds.json',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: ColorTheme.deepNavyBlue,
                          ),
                          children: [
                            const TextSpan(text: 'Create a '),
                            const TextSpan(
                              text: 'StarSight ',
                              style: TextStyle(color: ColorTheme.goldenYellow),
                            ),
                            const TextSpan(text: 'account to begin '),
                            TextSpan(text: '${widget.nickname}\'s'),
                            const TextSpan(text: ' adventure!'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // EMAIL AND PASSWORD FIELDS
                      Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 15,
                              color: ColorTheme.deepNavyBlue,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Email Address:',
                              labelStyle: const TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                fontSize: 14,
                                color: ColorTheme.deepNavyBlue,
                              ),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.deepNavyBlue,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 15,
                              color: ColorTheme.deepNavyBlue,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password:',
                              labelStyle: const TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                fontSize: 14,
                                color: ColorTheme.deepNavyBlue,
                              ),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: ColorTheme.deepNavyBlue,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.deepNavyBlue,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            // Fixed the controller name to match the top of your file!
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 15,
                              color: ColorTheme.deepNavyBlue,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password:',
                              labelStyle: const TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                fontSize: 14,
                                color: ColorTheme.deepNavyBlue,
                              ),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              // --- ADDED THE EYE ICON HERE ---
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: ColorTheme.deepNavyBlue,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              // -------------------------------
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.deepNavyBlue,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: ColorTheme.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),

                      SizedBox(
                        width: 190,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorTheme.deepNavyBlue,
                            foregroundColor: ColorTheme.cream,
                            elevation: 4,
                            shadowColor: ColorTheme.deepNavyBlue.withValues(
                              alpha: 0.45,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'SIGN UP',
                            style: TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ColorTheme.cream,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'or',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 14,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _onGoogleSignUp,
                        child: Image.asset(
                          'assets/images/buttons/google_signup.png',
                          height: 52,
                        ),
                      ),

                      const Spacer(),

                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: AppTextStyles.body,
                          children: [
                            TextSpan(text: 'By signing up, you agree to our '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: AppTextStyles.bodylink,
                            ),
                            TextSpan(text: '\nand '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTextStyles.bodylink,
                            ),
                            TextSpan(text: '.'),
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
      ),
    );
  }
}
