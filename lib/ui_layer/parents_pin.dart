import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/orientation_service.dart';
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

  bool _animationsReady = false;

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
        message: "Please enter all 4 digits of your Pin.",
      );
      return;
    }

    final enteredPin = _digits.join();

    String? realPin = await DatabaseService().getParentPin();

    if (!mounted) return;

    if (realPin != null && enteredPin == realPin) {
      Navigator.pop(context, true);
    } else {
      setState(() => _digits.clear());
      AppDialog.showError(
        context,
        message: "Incorrect Pin. Access Denied.",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    OrientationService.setLandscape();
    _loadAnimations();
  }

  @override
  void dispose() {
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _loadAnimations() async {
    await Future.wait([
      AssetLottie('assets/animations/doma_writing_onboard.json').load(),
    ]);
    if (mounted) {
      setState(() => _animationsReady = true);
    }
  }

  Widget _buildSlot(int index, double slotWidth) {
    final filled = index < _digits.length;
    final fontSize = (slotWidth * 0.55).clamp(16.0, 32.0);

    return SizedBox(
      width: slotWidth,
      child: Center(
        child: filled
            ? Text(
          _digits[index],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: Fonts.fredoka,
            color: ColorTheme.warmBrown,
          ),
        )
            : SizedBox(
          width: slotWidth * 0.6,
          height: slotWidth * 0.65,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ColorTheme.orange, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String label, double keyW, double keyH) {
    final isDelete = label == '⌫';
    final fontSize = (keyH * 0.38).clamp(12.0, 26.0);

    return GestureDetector(
      onTap: isDelete ? _onDelete : () => _onDigitTap(label),
      child: Container(
        width: keyW,
        height: keyH,
        decoration: BoxDecoration(
          color: ColorTheme.goldenYellow,
          borderRadius: BorderRadius.circular(keyH * 0.28),
        ),
        alignment: Alignment.center,
        child: isDelete
            ? Icon(Icons.backspace,
            color: ColorTheme.warmBrown, size: fontSize * 1.1)
            : Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: Fonts.fredoka,
            fontWeight: FontWeight.bold,
            color: ColorTheme.warmBrown,
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad(double panelW, double panelH) {
    const int cols = 3;
    final double usable = panelW * 0.70;
    final double gap = (usable * 0.07).clamp(6.0, 16.0);
    final double keyW =
    ((usable - gap * (cols - 1)) / cols).clamp(40.0, 100.0);
    final double keyH = (keyW * 0.75).clamp(36.0, 70.0);
    final double rowGap = (panelH * 0.04).clamp(6.0, 16.0);

    Widget row(List<String> labels) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: labels
          .map((l) => _buildKey(l, keyW, keyH))
          .expand((w) => [w, SizedBox(width: gap)])
          .toList()
        ..removeLast(),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        row(['1', '2', '3']),
        SizedBox(height: rowGap),
        row(['4', '5', '6']),
        SizedBox(height: rowGap),
        row(['7', '8', '9']),
        SizedBox(height: rowGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _onSubmit,
              child: Container(
                width: keyW,
                height: keyH,
                decoration: BoxDecoration(
                  color: ColorTheme.goldenYellow,
                  borderRadius: BorderRadius.circular(keyH * 0.28),
                ),
                child: Icon(Icons.check,
                    color: ColorTheme.warmBrown,
                    size: (keyH * 0.42).clamp(14.0, 28.0)),
              ),
            ),
            SizedBox(width: gap),
            _buildKey('0', keyW, keyH),
            SizedBox(width: gap),
            _buildKey('⌫', keyW, keyH),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final double h = constraints.maxHeight;

            // Left panel 40 %, right panel 60 %
            final double leftW = w * 0.50;
            final double rightW = w * 0.50;
            final double lottieSz = (h * 0.42).clamp(60.0, 150.0); // was 0.30
            final double titleSz = (h * 0.095).clamp(16.0, 34.0);  // was 0.075
            final double subtitleSz = (h * 0.050).clamp(10.0, 18.0); // was 0.038
            final double slotW = (h * 0.14).clamp(28.0, 58.0); // was 0.11
            final double vGapSm = h * 0.02;
            final double vGapMd = h * 0.04;

            return Row(
              children: [
                // ── LEFT: info + PIN display ──
                SizedBox(
                  width: leftW,
                  child: Center(
                    child: Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: leftW * 0.08),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _animationsReady
                              ? Lottie.asset(
                            'assets/animations/doma_writing_onboard.json',
                            width: lottieSz,
                          )
                              : Image.asset(
                            'assets/images/characters/doma_writing_on_board.png',
                            width: lottieSz,
                          ),
                          SizedBox(height: vGapSm),
                          Text(
                            "PARENTS ONLY",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSz,
                              fontFamily: Fonts.fredoka,
                              fontWeight: FontWeight.bold,
                              color: ColorTheme.orange,
                            ),
                          ),
                          SizedBox(height: vGapSm * 0.5),
                          Text(
                            "ENTER YOUR PIN TO CONTINUE",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleSz,
                              fontFamily: Fonts.fredoka,
                              fontWeight: FontWeight.bold,
                              color: ColorTheme.warmBrown,
                            ),
                          ),
                          SizedBox(height: vGapMd),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: slotW * 0.30,
                              vertical: slotW * 0.25,
                            ),
                            decoration: BoxDecoration(
                              color:
                              ColorTheme.cream.withValues(alpha: 0.25),
                              borderRadius:
                              BorderRadius.circular(slotW * 0.40),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _maxDigits,
                                    (i) => _buildSlot(i, slotW),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── RIGHT: numpad ──
                SizedBox(
                  width: rightW,
                  child: Center(
                    child: _buildNumpad(rightW, h),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}