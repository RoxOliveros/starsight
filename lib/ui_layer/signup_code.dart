import 'package:flutter/material.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class SignUpCode extends StatefulWidget {
  final String email;
  const SignUpCode({super.key, required this.email});

  @override
  State<SignUpCode> createState() => _SignUpCodeState();
}

class _SignUpCodeState extends State<SignUpCode> {
  final List<TextEditingController> _controllers =
  List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());


  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _onResend() {
    // TODO: handle resend code @Ron
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Penguin asset
              SizedBox(
                height: screenHeight * 0.30,
                width: double.infinity,
                child: Image.asset(
                  'assets/gifs/penguin_writing_onboard.gif',
                  fit: BoxFit.fitHeight,
                ),
              ),

              const SizedBox(height: 32),

              // Message
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ColorTheme.deepNavyBlue,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a magic code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                        text: ' ! Enter it\nhere to continue.\u201d'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 4-digit code input
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 55,
                    height: 55,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ColorTheme.deepNavyBlue,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ColorTheme.deepNavyBlue,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: '—',
                        hintStyle: TextStyle(
                          color: ColorTheme.deepNavyBlue,
                          fontSize: 18,
                        ),
                      ),
                      onChanged: (value) => _onChanged(value, index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Resend
              GestureDetector(
                onTap: _onResend,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 13,
                      color: ColorTheme.deepNavyBlue,
                    ),
                    children: [
                      TextSpan(text: "Didn't receive it? "),
                      TextSpan(
                        text: 'Resend code',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ColorTheme.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Bottom note
              const Text(
                'Your code may take a little while to travel\nthrough the stars. Please check your inbox and\nspam folder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorTheme.deepNavyBlue,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}