import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'app_dialog.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class ParentPinVerification extends StatefulWidget {
  const ParentPinVerification({super.key});

  @override
  State<ParentPinVerification> createState() => _ParentPinVerificationState();
}

class _ParentPinVerificationState extends State<ParentPinVerification> {
  final List<String> _pin = [];
  final List<String> _confirmPin = [];
  static const int _maxDigits = 4;
  bool _isConfirmStep = false;

  void _onDigitTap(String digit) {
    final current = _isConfirmStep ? _confirmPin : _pin;
    if (current.length < _maxDigits) {
      setState(() => current.add(digit));
    }
  }

  void _onDelete() {
    final current = _isConfirmStep ? _confirmPin : _pin;
    if (current.isNotEmpty) {
      setState(() => current.removeLast());
    }
  }

  void _onComplete() {
    if (!_isConfirmStep) {
      setState(() => _isConfirmStep = true);
    } else {
      if (_pin.join() == _confirmPin.join()) {
        // TODO: save PIN @Ron
        // TODO: navigate to dashboard @Tin
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => const [Dashboard](),
        //   ),
        // );
      } else {
        AppDialog.showError(context, message: "PINs do not match. Try again.");
        setState(() {
          _confirmPin.clear();
          _isConfirmStep = false;
          _pin.clear();
        });
      }
    }
  }

  Widget _buildDigitSlot(int index) {
    final current = _isConfirmStep ? _confirmPin : _pin;
    final filled = index < current.length;
    return Container(
      width: 36,
      height: 40,
      alignment: Alignment.center,
      child: filled
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: ColorTheme.warmBrown,
                shape: BoxShape.circle,
              ),
            )
          : Container(
              width: 28,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ColorTheme.warmBrown, width: 2),
                ),
              ),
              height: 32,
            ),
    );
  }

  Widget _buildKey(String label) {
    final isDelete = label == '⌫';
    return GestureDetector(
      onTap: isDelete ? _onDelete : () => _onDigitTap(label),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: ColorTheme.goldenYellow,
          borderRadius: BorderRadius.circular(23),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFc8a84b),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isDelete
            ? const Icon(
                Icons.backspace_rounded,
                color: ColorTheme.warmBrown,
                size: 22,
              )
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

  Widget _buildNextButton() {
    final current = _isConfirmStep ? _confirmPin : _pin;
    final bool isReady = current.length == _maxDigits;
    return GestureDetector(
      onTap: isReady ? _onComplete : null,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: isReady
              ? ColorTheme.goldenYellow
              : ColorTheme.goldenYellow.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isReady
              ? const [
                  BoxShadow(
                    color: Color(0xFFc8a84b),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_forward_rounded,
          color: isReady
              ? ColorTheme.warmBrown
              : ColorTheme.warmBrown.withValues(alpha: 0.4),
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: ColorTheme.deepNavyBlue,
      body: Stack(
        children: [
          // Top-right cloud
          Positioned(
            top: screenHeight * 0.04,
            right: -100,
            child: Image.asset(
              'assets/gifs/night_cloud_fluffy.gif',
              width: screenWidth * 0.65,
              opacity: const AlwaysStoppedAnimation(0.85),
            ),
          ),
          // Bottom-left cloud
          Positioned(
            bottom: screenHeight * -0.09,
            left: -130,
            child: Image.asset(
              'assets/gifs/night_cloud.gif',
              width: screenWidth * 0.80,
              opacity: const AlwaysStoppedAnimation(0.85),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back button  ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),

                // ── Rest of your screen ──
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: screenHeight * 0.1),

                        // Dog + message row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 150,
                                child: OverflowBox(
                                  maxWidth: 160,
                                  child: Image.asset(
                                    'assets/gifs/dancing_dog.gif',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _isConfirmStep
                                      ? 'Re-enter your PIN to confirm'
                                      : 'Parents, please create a 4-digit PIN',
                                  style: const TextStyle(
                                    color: Color(0xFFFAF7EB),
                                    fontSize: 18,
                                    fontFamily: Fonts.fredoka,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Input display
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 45),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTheme.cream.withValues(alpha: 0.39),
                              border: Border.all(
                                color: ColorTheme.deepNavyBlue.withValues(
                                  alpha: 0.70,
                                ),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                _maxDigits,
                                (i) => _buildDigitSlot(i),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Numpad
                        Column(
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
                                _buildNextButton(),
                                _buildKey('0'),
                                _buildKey('⌫'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
