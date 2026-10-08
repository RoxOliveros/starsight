import 'package:StarSight/ui_layer/app_dialog.dart';
import 'package:StarSight/ui_layer/child_gender_screen.dart';
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/audio_helper.dart';
import 'appbar_signup.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color darkBlue = Color(0xFF5F7199);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class ChildBirthdateScreen extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;

  const ChildBirthdateScreen({
    super.key,
    required this.nickname,
    required this.parentBirthYear,
  });

  @override
  State<ChildBirthdateScreen> createState() => _ChildBirthdateScreenState();
}

class _ChildBirthdateScreenState extends State<ChildBirthdateScreen> {
  DateTime? _selectedDate;

  void _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorTheme.goldenYellow,
              onPrimary: ColorTheme.warmBrown,
              surface: ColorTheme.cream,
              onSurface: ColorTheme.warmBrown,
            ),
            dialogBackgroundColor: ColorTheme.cream,
            datePickerTheme: DatePickerThemeData(
              backgroundColor: ColorTheme.cream,
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shadowColor: const Color(0xFF3A4F6E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: ColorTheme.darkBlue,
              headerForegroundColor: ColorTheme.cream,
              headerHeadlineStyle: const TextStyle(
                fontFamily: Fonts.fredoka,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
              headerHelpStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: const TextStyle(
                fontFamily: Fonts.fredoka,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorTheme.darkBlue,
              ),
              dayStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              yearStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return ColorTheme.warmBrown.withValues(alpha: 0.3);
                }
                return ColorTheme.warmBrown;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return ColorTheme.goldenYellow;
                }
                return Colors.transparent;
              }),
              dayOverlayColor: WidgetStateProperty.all(
                ColorTheme.goldenYellow.withValues(alpha: 0.25),
              ),
              todayForegroundColor: WidgetStateProperty.all(ColorTheme.warmBrown),
              todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
              todayBorder: const BorderSide(
                color: ColorTheme.goldenYellow,
                width: 2,
              ),
              yearForegroundColor: WidgetStateProperty.all(ColorTheme.warmBrown),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return ColorTheme.goldenYellow;
                }
                return Colors.transparent;
              }),
              yearOverlayColor: WidgetStateProperty.all(
                ColorTheme.goldenYellow.withValues(alpha: 0.25),
              ),
              dividerColor: ColorTheme.darkBlue.withValues(alpha: 0.2),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: ColorTheme.darkBlue,
                textStyle: const TextStyle(
                  fontFamily: Fonts.fredoka,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: ColorTheme.warmBrown,
                backgroundColor: ColorTheme.goldenYellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(
                  fontFamily: Fonts.fredoka,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            textTheme: base.textTheme.copyWith(
              titleSmall: const TextStyle(
                fontFamily: Fonts.fredoka,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorTheme.warmBrown,
              ),
            ),
            iconTheme: const IconThemeData(color: ColorTheme.darkBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      SfxHelper.instance.play(Sfx.keyTap);
      setState(() => _selectedDate = picked);
    }
  }

  void _onNext() {
    int currentYear = DateTime.now().year;
    int parentYear = int.tryParse(widget.parentBirthYear) ?? 0;
    int childYear = _selectedDate!.year;

    int childAge = currentYear - childYear;
    int ageDifference = childYear - parentYear;

    if (childAge < 3) {
      AppDialog.showError(
        context,
        message: "The child must be at least 3 years old to register.",
      );
      return;
    }

    if (ageDifference < 18) {
      AppDialog.showError(
        context,
        message:
            "Invalid birthdate. The Grownup must be at least 18 years older than the child.",
      );
      return;
    }

    String formattedDate =
        "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChildGenderScreen(
              nickname: widget.nickname,
              childBirthdate: formattedDate,
              parentBirthYear: widget.parentBirthYear,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isReady = _selectedDate != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          Positioned(
            top: screenHeight * 0.65,
            right: -130,
            child: Lottie.asset(
              'assets/animations/night_cloud_fluffy.json',
              width: screenWidth * 0.80,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.90,
            left: -130,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.80,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),
          Positioned(
            top: screenHeight * 0.70,
            left: screenWidth * 0.20,
            child: Transform.rotate(
              angle: 0.4,
              child: Image.asset('assets/images/night_star.png', width: 40),
            ),
          ),
          Positioned(
            top: screenHeight * 0.60,
            right: screenWidth * 0.35,
            child: Transform.rotate(
              angle: 0.9,
              child: Image.asset('assets/images/night_star.png', width: 50),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.02,
            left: screenWidth * 0.01,
            child: Transform.rotate(
              angle: 0.6,
              child: Image.asset('assets/images/night_star.png', width: 100),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.09,
            right: screenWidth * 0.06,
            child: Transform.rotate(
              angle: 0.3,
              child: Image.asset('assets/images/night_star.png', width: 60),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTopBar(progress: 0.65),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: screenHeight * 0.04),
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
                                  child: Lottie.asset(
                                    'assets/animations/dancing_dog.json',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerRight,
                                  ),
                                ),
                              ),
                      Expanded(
                        child: Text(
                          "When is ${widget.nickname}'s birthday?",
                          style: const TextStyle(
                            color: ColorTheme.cream,
                            fontSize: 18,
                            fontFamily: Fonts.fredoka,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Birthdate",
                        style: TextStyle(
                          color: ColorTheme.cream,
                          fontSize: 16,
                          fontFamily: Fonts.fredoka,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: (){
                          SfxHelper.instance.play(Sfx.keyTap);
                          _selectDate();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: _selectedDate != null
                                  ? ColorTheme.goldenYellow
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _selectedDate != null
                                    ? ColorTheme.goldenYellow
                                    : ColorTheme.goldenYellow.withValues(
                                        alpha: 0.6,
                                      ),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _selectedDate != null
                                    ? "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}"
                                    : "Select Birthdate",
                                style: TextStyle(
                                  fontFamily: Fonts.fredoka,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedDate != null
                                      ? ColorTheme.cream
                                      : ColorTheme.cream.withValues(
                                          alpha: 0.75,
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

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isReady
                                ? () {
                              SfxHelper.instance.play(Sfx.keyTap);
                              _onNext();
                            }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorTheme.goldenYellow,
                              disabledBackgroundColor: ColorTheme.goldenYellow
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0xFF3A4F6E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                            ),
                            child: const Text(
                              'NEXT',
                              style: TextStyle(
                                fontFamily: Fonts.fredoka,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ColorTheme.warmBrown,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          SfxHelper.instance.play(Sfx.keyTap);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInAccount(),
                            ),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: ColorTheme.cream,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: 'Have an account? ',
                                style: TextStyle(fontFamily: Fonts.fredoka),
                              ),
                              TextSpan(
                                text: 'Sign in here!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: Fonts.fredoka,
                                  decoration: TextDecoration.underline,
                                  color: Colors.white,
                                ),
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