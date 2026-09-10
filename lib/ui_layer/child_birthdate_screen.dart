import 'package:StarSight/ui_layer/app_dialog.dart';
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
import 'package:StarSight/ui_layer/parents_pin_setup.dart';
========
import 'package:StarSight/ui_layer/child_gender_screen.dart';
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
import 'package:StarSight/ui_layer/signin_account.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
class ChildDetailsScreen extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;

  const ChildDetailsScreen({
========
class ChildBirthdateScreen extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;

  const ChildBirthdateScreen({
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
    super.key,
    required this.nickname,
    required this.parentBirthYear,
  });

  @override
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  DateTime? _selectedDate;
  String? _selectedGender;

  final List<String> _genders = ['Boy', 'Girl'];

========
  State<ChildBirthdateScreen> createState() => _ChildBirthdateScreenState();
}

class _ChildBirthdateScreenState extends State<ChildBirthdateScreen> {
  DateTime? _selectedDate;

>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
  void _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ColorTheme.goldenYellow,
              onPrimary: ColorTheme.warmBrown,
              onSurface: ColorTheme.darkBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _onNext() {
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
    // 1. Calculate the current year, ages, and the age difference
========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
    int currentYear = DateTime.now().year;
    int parentYear = int.tryParse(widget.parentBirthYear) ?? 0;
    int childYear = _selectedDate!.year;

    int childAge = currentYear - childYear;
    int ageDifference = childYear - parentYear;

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
    // 2. Validate Child Age (must be 3 to 5 years old)
========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
    if (childAge < 3 || childAge > 5) {
      AppDialog.showError(
        context,
        message: "The child must be between 3 and 5 years old to register.",
      );
      return;
    }

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
    // 3. Validate Age Difference (parent must be at least 20 years older than the child)
========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
    if (ageDifference < 20) {
      AppDialog.showError(
        context,
        message:
            "Invalid birthdate. The parent must be at least 20 years older than the child.",
      );
      return;
    }

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
    // If validation passes, proceed normally!
========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
    String formattedDate =
        "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
            ParentPinVerification(
              nickname: widget.nickname,
              childBirthdate: formattedDate,
              childGender: _selectedGender!,
========
            ChildGenderScreen(
              nickname: widget.nickname,
              childBirthdate: formattedDate,
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
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
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
    final bool isReady = _selectedDate != null && _selectedGender != null;
========
    final bool isReady = _selectedDate != null;
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart

    return Scaffold(
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          Positioned(
            bottom: screenHeight * 0.12,
            left: -80,
            child: Lottie.asset(
              'assets/animations/night_cloud.json',
              width: screenWidth * 0.65,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.opacity(const ['**'], value: 85),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTopBar(progress: 0.65),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 120,
                        child: OverflowBox(
                          maxWidth: 140,
                          child: Lottie.asset(
                            'assets/animations/dancing_dog.json',
                            fit: BoxFit.contain,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
                          'Tell us a bit more about ${widget.nickname}!',
========
                          "When is ${widget.nickname}'s birthday?",
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
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

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
                // Date Picker UI
========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
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
                        onTap: _selectDate,
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

<<<<<<<< HEAD:lib/ui_layer/child_details_screen.dart.dart
                const SizedBox(height: 24),

                // Gender Selection UI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Gender",
                        style: TextStyle(
                          color: ColorTheme.cream,
                          fontSize: 16,
                          fontFamily: Fonts.fredoka,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: _genders.map((gender) {
                          final isSelected = _selectedGender == gender;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGender = gender;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ColorTheme.goldenYellow.withValues(
                                          alpha: 0.35,
                                        )
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: isSelected
                                        ? ColorTheme.goldenYellow
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: isSelected
                                          ? ColorTheme.goldenYellow
                                          : ColorTheme.goldenYellow.withValues(
                                              alpha: 0.6,
                                            ),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      gender,
                                      style: TextStyle(
                                        fontFamily: Fonts.fredoka,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
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
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

========
>>>>>>>> fetures/Scrum-134-Add-Child's-Gender:lib/ui_layer/child_birthdate_screen.dart
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
                            onPressed: isReady ? _onNext : null,
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
        ],
      ),
    );
  }
}
