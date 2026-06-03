import 'package:StarSight/business_layer/otp_screen.dart';
import 'package:StarSight/ui_layer/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/auth_service.dart';
import '../business_layer/database_service.dart';
import '../business_layer/orientation_service.dart';
import 'app_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

class SignInAccount extends StatefulWidget {
  const SignInAccount({super.key});

  @override
  State<SignInAccount> createState() => _SignInAccountState();
}

class _SignInAccountState extends State<SignInAccount>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
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
    _phoneController.dispose();
    super.dispose();
  }

  void _onSignIn() async {
    String phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      AppDialog.showError(
        context,
        message: "Please enter a valid phone number (e.g., +639123456789)",
      );
      return;
    }

    // Since we saved the phone number into the 'email' database field during signup,
    // we can safely use your existing doesEmailExist function to check if the phone exists!
    bool accountExists = await DatabaseService().doesEmailExist(phone);

    if (!accountExists) {
      if (!mounted) return;
      AppDialog.showError(
        context,
        message: "Account not found! Please go back and Sign Up first.",
      );
      return;
    }

    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Call AuthService to send the SMS
    await AuthService().verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: (String verificationId) {
        Navigator.pop(context); // Remove loading circle

        // Navigate to the Penguin OTP screen!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              phoneNumber: phone,
              verificationId: verificationId,
              onSuccess: () async {
                // SUCCESS! Get the nickname and go straight to the Dashboard!
                String fetchedNickname = await DatabaseService().getNickname();
                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DashboardScreen(nickname: fetchedNickname),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
      },
      onError: (String error) {
        Navigator.pop(context); // Remove loading circle
        AppDialog.showError(context, message: error);
      },
      onVerificationCompleted: () async {
        // Automatically reads SMS on Android and logs them in!
        Navigator.pop(context); // Remove loading circle
        String fetchedNickname = await DatabaseService().getNickname();
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(nickname: fetchedNickname),
          ),
          (route) => false,
        );
      },
    );
  }

  void _onGoogleSignIn() async {
    bool success = await AuthService().signInWithGoogle();

    if (success) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        bool emailExists = await DatabaseService().doesEmailExist(
          user.email ?? '',
        );

        if (!emailExists) {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn.instance.signOut();

          if (!mounted) return;
          AppDialog.showError(
            context,
            message: "Account not found! Please go back and Sign Up first.",
          );
          return;
        }

        String fetchedNickname = await DatabaseService().getNickname();

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(nickname: fetchedNickname),
          ),
          (route) => false,
        );
      }
    } else {
      if (!mounted) return;
      AppDialog.showError(
        context,
        message: "Google Sign-In was canceled or failed.",
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
              // Cloud top
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
                      // Title
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
                            const TextSpan(
                              text: 'Welcome back Parents!\nLog in to your ',
                            ),
                            const TextSpan(
                              text: 'StarSight',
                              style: TextStyle(color: ColorTheme.goldenYellow),
                            ),
                            const TextSpan(text: '\naccount.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email field
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 15,
                          color: ColorTheme.deepNavyBlue,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number (+63):',
                          labelStyle: const TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 14,
                            color: ColorTheme.deepNavyBlue,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
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

                      const SizedBox(height: 80),

                      // Log in button
                      SizedBox(
                        width: 190,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onSignIn,
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
                            'LOG IN',
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

                      // Or divider
                      const Text(
                        'or',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 14,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Google Sign In button
                      GestureDetector(
                        onTap: _onGoogleSignIn,
                        child: Image.asset(
                          'assets/images/buttons/google_signin.png',
                          height: 52,
                        ),
                      ),

                      const Spacer(),

                      // Terms
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: AppTextStyles.body,
                          children: [
                            TextSpan(text: 'By signing in, you agree to our '),
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
