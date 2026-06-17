import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import '../business_layer/auth_service.dart';
import 'app_dialog.dart' hide ColorTheme;

class PasswordResetScreen extends StatefulWidget {
  final String oobCode;

  const PasswordResetScreen({super.key, required this.oobCode});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureconfirmPassword = true;
  bool _isSaving = false;

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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSavePassword() async {
    if (_isSaving) return;
    String newPassword = _passwordController.text.trim();
    String confirm = _confirmController.text.trim();

    if (newPassword.length < 6) {
      AppDialog.showError(
        context,
        message: "Password must be at least 6 characters.",
      );
      return;
    }
    if (newPassword != confirm) {
      AppDialog.showError(context, message: "Passwords do not match!");
      return;
    }
    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Send the secret code and new password to Firebase!
    String? error = await AuthService().confirmPasswordReset(
      code: widget.oobCode,
      newPassword: newPassword,
    );

    if (!mounted) return;
    Navigator.pop(context); // remove loading circle
    setState(() => _isSaving = false);

    if (error == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            "Success!",
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              color: ColorTheme.deepNavyBlue,
            ),
          ),
          content: const Text(
            "Your password has been reset. You can now log in!",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInAccount()),
                      (route) => false,
                );
              },
              child: const Text("GO TO LOGIN"),
            ),
          ],
        ),
      );
    } else {
      AppDialog.showError(context, message: error);
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
                      const Text(
                        "Create New Password",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Please type a new, strong password below.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 15,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // PASSWORD FIELDS
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 15,
                              color: ColorTheme.deepNavyBlue,
                            ),
                            decoration: InputDecoration(
                              labelText: 'New Password:',
                              labelStyle: const TextStyle(
                                fontFamily: 'Fredoka',
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
                                onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                ),
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
                            controller: _confirmController,
                            obscureText: _obscureconfirmPassword,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 15,
                              color: ColorTheme.deepNavyBlue,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password:',
                              labelStyle: const TextStyle(
                                fontFamily: 'Fredoka',
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
                                  _obscureconfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: ColorTheme.deepNavyBlue,
                                ),
                                onPressed: () => setState(
                                      () => _obscureconfirmPassword = !_obscureconfirmPassword,
                                ),
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
                        ],
                      ),

                      const SizedBox(height: 50),

                      SizedBox(
                        width: 210,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _onSavePassword,
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
                            'SAVE PASSWORD',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ColorTheme.cream,
                            ),
                          ),
                        ),
                      ),

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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}