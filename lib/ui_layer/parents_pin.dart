import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'app_dialog.dart';
import '../business_layer/database_service.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color darkBlue = Color(0xFF5F7199);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
  static const Color orange = Color(0xFFEC8A20);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class ParentPin extends StatefulWidget {
  const ParentPin({super.key});

  @override
  State<ParentPin> createState() => ParentPinState();
}

class ParentPinState extends State<ParentPin> {
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

  void _onSubmit() async {
    if (_digits.length < _maxDigits) {
      AppDialog.showError(
        context,
        message: "Please enter all 4 digits of your birth year.",
      );
      return;
    }

    final enteredPin = _digits.join();

    // 1. Show a loading indicator if you want, because we have to ask the internet!

    // 2. Go get the real PIN from the database
    String? realPin = await DatabaseService().getParentBirthYear();

    if (!mounted) return;

    // 3. Make the exact match!
    if (realPin != null && enteredPin == realPin) {
      // SUCCESS! It matches exactly what they typed during Sign-Up.
      Navigator.pop(context, true);
    } else {
      // FAILURE! Wrong PIN.
      setState(() => _digits.clear());
      AppDialog.showError(
        context,
        message: "Incorrect Birth Year. Access Denied.",
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Widget _buildSlot(int index) {
    final filled = index < _digits.length;

    return Container(
      width: 45,
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
              height: 32,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ColorTheme.orange, width: 2),
                ),
              ),
            ),
    );
  }

  Widget _buildKey(String label) {
    final isDelete = label == '⌫';

    return GestureDetector(
      onTap: isDelete ? _onDelete : () => _onDigitTap(label),
      child: Container(
        width: 75,
        height: 58,
        decoration: BoxDecoration(
          color: ColorTheme.goldenYellow,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: isDelete
            ? const Icon(Icons.backspace, color: ColorTheme.warmBrown)
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

  Widget _buildNumpad() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
            GestureDetector(
              onTap: _onSubmit,
              child: Container(
                width: 75,
                height: 58,
                decoration: BoxDecoration(
                  color: ColorTheme.goldenYellow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.check, color: ColorTheme.warmBrown),
              ),
            ),
            _buildKey('0'),
            _buildKey('⌫'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,

      body: SafeArea(
        child: Row(
          children: [
            // ───────── LEFT SIDE ─────────
            Expanded(
              flex: 2,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // ✅ key fix
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🐧 Penguin
                      Lottie.asset(
                        'assets/animations/penguin_writing_onboard.json',
                        width: 140,
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "PARENTS ONLY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontFamily: Fonts.fredoka,
                          fontWeight: FontWeight.bold,
                          color: ColorTheme.orange,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "ENTER YOUR BIRTHYEAR TO CONTINUE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: Fonts.fredoka,
                          fontWeight: FontWeight.bold,
                          color: ColorTheme.warmBrown,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Input display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTheme.cream.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min, // ✅ keeps input centered tight
                          children: List.generate(
                            _maxDigits,
                            (i) => _buildSlot(i),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ───────── RIGHT SIDE ─────────
            Expanded(flex: 3, child: Center(child: _buildNumpad())),
          ],
        ),
      ),
    );
  }
}
