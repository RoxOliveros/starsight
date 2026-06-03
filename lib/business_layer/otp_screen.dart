import 'package:StarSight/business_layer/auth_service.dart';
import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
}

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final VoidCallback onSuccess;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.onSuccess,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyCode() async {
    if (_otpController.text.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    bool success = await AuthService().verifyOTP(
      verificationId: widget.verificationId,
      smsCode: _otpController.text,
    );

    if (success) {
      widget.onSuccess(); // Triggers the database save or navigation!
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid code. Please try again.';
        _otpController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. The Penguin Image
                Image.asset(
                  'assets/images/characters/doma_writing_on_board.png',
                  height: 200,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 32),

                // 2. The Text
                Text(
                  "We sent a magic code to\n${widget.phoneNumber}! Enter it\nhere to continue.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ColorTheme.deepNavyBlue,
                  ),
                ),

                const SizedBox(height: 40),

                // 3. The Custom 6-Digit Input
                GestureDetector(
                  onTap: () => FocusScope.of(context).requestFocus(_focusNode),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The invisible text field that actually catches the keyboard typing
                      Opacity(
                        opacity: 0.0,
                        child: TextField(
                          controller: _otpController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          autofocus: true,
                          onChanged: (val) {
                            setState(() {}); // Rebuild to show typed numbers
                            if (val.length == 6) _verifyCode(); // Auto-submit!
                          },
                        ),
                      ),

                      // The visual boxes from your Figma mockup
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: ColorTheme.deepNavyBlue,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            String char = '';
                            if (_otpController.text.length > index) {
                              char = _otpController.text[index];
                            }
                            return Container(
                              width: 35,
                              height: 45,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: ColorTheme.deepNavyBlue,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                char,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: ColorTheme.deepNavyBlue,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],

                const SizedBox(height: 24),

                // 4. Resend Code Text
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 14,
                      color: ColorTheme.deepNavyBlue,
                    ),
                    children: [
                      TextSpan(text: "Didn't receive it? "),
                      TextSpan(
                        text: "Resend code",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // 5. Bottom Disclaimer
                const Text(
                  "Your code may take a little while to travel\nthrough the stars. Please check your SMS.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorTheme.deepNavyBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
