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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

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
    super.dispose();
  }

  void _onSignIn() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppDialog.showError(
        context,
        message: "Please enter your email and password.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? error = await AuthService().signInWithEmail(email, password);

    if (!mounted) return;
    Navigator.pop(context);

    if (error == null) {
      String? fetchedNickname = await DatabaseService().getNickname();
      if (!mounted) return;

      if (fetchedNickname == null) {
        // Delete the broken Auth account!
        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (e) {
          print("Failed to delete ghost account: $e");
        }

        await FirebaseAuth.instance.signOut(); // Force log them out

        AppDialog.showError(
          context,
          message:
              "Profile data was missing! We have cleaned up the corrupted account. You can now successfully Sign Up again.",
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(nickname: fetchedNickname),
        ),
        (route) => false,
      );
    } else {
      AppDialog.showError(context, message: error);
    }
  }

  void _onForgotPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      AppDialog.showError(
        context,
        message:
            "Please type your email address in the box above first, then click 'Forgot Password'.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool emailExists = await DatabaseService().doesEmailExist(email);

    if (!emailExists) {
      if (!mounted) return;
      Navigator.pop(context);

      AppDialog.showError(
        context,
        message:
            "We couldn't find an account with that email. Please check for typos or sign up first.",
      );
      return;
    }

    String? error = await AuthService().sendPasswordResetEmail(email);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading circle

    if (error == null) {
      AppDialog.showSuccess(
        context,
        message:
            "Check your inbox for a link to reset your password.\n\nBe sure to check your spam folder!",
      );
    } else {
      AppDialog.showError(context, message: error);
    }
  }

  void _onGoogleSignIn() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool success = await AuthService().signInWithGoogle();

    if (success) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        bool emailExists = await DatabaseService().doesEmailExist(
          user.email ?? '',
        );

        if (!emailExists) {
          try {
            await FirebaseAuth.instance.currentUser?.delete();
          } catch (e) {
            print("Failed to delete ghost account: $e");
          }

          await FirebaseAuth.instance.signOut();
          await GoogleSignIn.instance.signOut();

          if (!mounted) return;
          Navigator.pop(context);
          AppDialog.showError(
            context,
            message: "Account not found! Please go back and Sign Up first.",
          );
          return;
        }

        String? fetchedNickname = await DatabaseService().getNickname();

        if (!mounted) return;
        Navigator.pop(context);

        if (fetchedNickname == null) {
          try {
            await FirebaseAuth.instance.currentUser?.delete();
          } catch (e) {
            print("Failed to delete ghost account: $e");
          }

          await FirebaseAuth.instance.signOut();
          await GoogleSignIn.instance.signOut();

          AppDialog.showError(
            context,
            message:
                "Profile data was missing! We have cleaned up the corrupted account. You can now successfully Sign Up again.",
          );
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(nickname: fetchedNickname),
          ),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context);
      }
    } else {
      if (!mounted) return;
      Navigator.pop(context);
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
      appBar: AppBar(
        backgroundColor: ColorTheme.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorTheme.deepNavyBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: ColorTheme.deepNavyBlue,
                          ),
                          children: [
                            TextSpan(
                              text: 'Welcome back Parents!\nLog in to your ',
                            ),
                            TextSpan(
                              text: 'StarSight',
                              style: TextStyle(color: ColorTheme.goldenYellow),
                            ),
                            TextSpan(text: '\naccount.'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // EMAIL AND PASSWORD FIELDS
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
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
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
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
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _onForgotPassword,
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                color: ColorTheme.deepNavyBlue,
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
                        onTap: _onGoogleSignIn,
                        child: Image.asset(
                          'assets/images/buttons/google_signin.png',
                          height: 52,
                        ),
                      ),

                      const Spacer(),

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
