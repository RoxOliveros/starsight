import 'package:flutter/material.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import '../business_layer/auth_service.dart';
import 'app_dialog.dart' hide ColorTheme;

class PasswordResetScreen extends StatefulWidget {
  final String oobCode;

  const PasswordResetScreen({super.key, required this.oobCode});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;

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
      backgroundColor: ColorTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ColorTheme.deepNavyBlue),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Create New Password",
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
              const SizedBox(height: 40),

              // New Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'New Password:',
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: ColorTheme.deepNavyBlue,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              TextField(
                controller: _confirmController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password:',
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
              const SizedBox(height: 50),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSavePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorTheme.deepNavyBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'SAVE PASSWORD',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 18,
                      color: ColorTheme.cream,
                      fontWeight: FontWeight.bold,
                    ),
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
