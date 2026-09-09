<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
import 'package:StarSight/ui_layer/parents_pin_setup.dart';
========
import 'package:StarSight/ui_layer/app_dialog.dart';
import 'package:StarSight/ui_layer/child_gender_screen.dart';
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
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

<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
class ChildGoal extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;

  const ChildGoal({
========
class ChildBirthdateScreen extends StatefulWidget {
  final String nickname;
  final String parentBirthYear;

  const ChildBirthdateScreen({
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
    super.key,
    required this.nickname,
    required this.parentBirthYear,
  });

  @override
<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
  State<ChildGoal> createState() => _ChildGoalState();
}

class _ChildGoalState extends State<ChildGoal> {
  final List<String> _goals = [
    'READING',
    'MATH',
    'PROBLEM SOLVING',
    'FOCUS/ATTENTION',
    'MEMORY',
    'VALUE',
  ];

  final Set<int> _selectedIndices = {};

  void _onNext() {
    List<String> selectedGoals = _selectedIndices
        .map((i) => _goals[i])
        .toList();
========
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
    int currentYear = DateTime.now().year;
    int parentYear = int.tryParse(widget.parentBirthYear) ?? 0;
    int childYear = _selectedDate!.year;

    int childAge = currentYear - childYear;
    int ageDifference = childYear - parentYear;

    if (childAge < 3 || childAge > 5) {
      AppDialog.showError(
        context,
        message: "The child must be between 3 and 5 years old to register.",
      );
      return;
    }

    if (ageDifference < 20) {
      AppDialog.showError(
        context,
        message:
            "Invalid birthdate. The parent must be at least 20 years older than the child.",
      );
      return;
    }

    String formattedDate =
        "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
        pageBuilder: (context, animation, secondaryAnimation) => ParentPinVerification(
          nickname: widget.nickname,
          goals: selectedGoals,
          parentBirthYear: widget.parentBirthYear,
        ),
========
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChildGenderScreen(
              nickname: widget.nickname,
              childBirthdate: formattedDate,
              parentBirthYear: widget.parentBirthYear,
            ),
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
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
<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
========
    final bool isReady = _selectedDate != null;
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart

    return Scaffold(
      backgroundColor: ColorTheme.darkBlue,
      body: Stack(
        children: [
          // Cloud decoration bottom left
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
                AppTopBar(progress: 0.65), // Adjusted progress

                // Header row
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
<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
                          'Which areas would you like ${widget.nickname} to work on? (Select all that apply)',
========
                          "When is ${widget.nickname}'s birthday?",
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
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

                const SizedBox(height: 8),

<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
                // Goal options
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final isSelected = _selectedIndices.contains(i);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIndices.remove(i);
                            } else {
                              _selectedIndices.add(i);
                            }
                          });
                        },
========
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
>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: isSelected
                                    ? ColorTheme.goldenYellow
                                    : ColorTheme.goldenYellow.withValues(
                                        alpha: 0.6,
                                      ),
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _goals[i],
                                style: TextStyle(
                                  fontFamily: Fonts.fredoka,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? ColorTheme.cream
                                      : ColorTheme.cream.withValues(
                                          alpha: 0.75,
                                        ),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

<<<<<<<< Updated upstream:lib/ui_layer/child_goal.dart
                // Bottom buttons
========
                const Spacer(),

>>>>>>>> Stashed changes:lib/ui_layer/child_birthdate_screen.dart
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
                            onPressed: _selectedIndices.isNotEmpty
                                ? _onNext
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
