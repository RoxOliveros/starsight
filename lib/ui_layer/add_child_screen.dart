import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'app_dialog.dart';
import '../business_layer/database_service.dart';

abstract class ColorTheme {
  static const Color goldenYellow = Color(0xFFFBD481);
  static const Color darkBlue = Color(0xFF5F7199);
  static const Color warmBrown = Color(0xFF5E463E);
  static const Color cream = Color(0xFFFAF7EB);
}

abstract class Fonts {
  static const String fredoka = 'Fredoka';
}

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

enum _Step { nickname, birthdate, gender }

class _AddChildScreenState extends State<AddChildScreen> {
  _Step _step = _Step.nickname;
  bool _saving = false;

  final TextEditingController _nicknameController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  final List<String> _genders = ['Boy', 'Girl'];

  // Fetched lazily so we can keep enforcing "parent is 20+ years older than
  // child" the same way the original signup flow does. If it can't be
  // loaded for some reason, we just skip that particular check rather than
  // blocking the parent from adding a child.
  String? _parentBirthYear;

  @override
  void initState() {
    super.initState();
    DatabaseService().getParentBirthYear().then((year) {
      if (mounted) setState(() => _parentBirthYear = year);
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  double get _progress {
    switch (_step) {
      case _Step.nickname:
        return 0.34;
      case _Step.birthdate:
        return 0.67;
      case _Step.gender:
        return 1.0;
    }
  }

  void _goBack() {
    switch (_step) {
      case _Step.nickname:
        Navigator.pop(context);
        break;
      case _Step.birthdate:
        setState(() => _step = _Step.nickname);
        break;
      case _Step.gender:
        setState(() => _step = _Step.birthdate);
        break;
    }
  }

  void _onNicknameNext() {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      AppDialog.showError(context, message: "Nickname should not be empty");
      return;
    }
    if (RegExp(r'[0-9]').hasMatch(nickname)) {
      AppDialog.showError(
        context,
        message: "Nicknames cannot contain numbers. Letters only, please!",
      );
      return;
    }
    if (nickname.contains(' ')) {
      AppDialog.showError(
        context,
        message: "Nickname should not contain any spaces",
      );
      return;
    }
    setState(() => _step = _Step.birthdate);
  }

  Future<void> _selectDate() async {
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

  void _onBirthdateNext() {
    final int currentYear = DateTime.now().year;
    final int childYear = _selectedDate!.year;
    final int childAge = currentYear - childYear;

    if (childAge < 3 || childAge > 5) {
      AppDialog.showError(
        context,
        message: "The child must be between 3 and 5 years old to register.",
      );
      return;
    }

    final int? parentYear = int.tryParse(_parentBirthYear ?? '');
    if (parentYear != null) {
      final int ageDifference = childYear - parentYear;
      if (ageDifference < 20) {
        AppDialog.showError(
          context,
          message:
              "Invalid birthdate. The parent must be at least 20 years older than the child.",
        );
        return;
      }
    }

    setState(() => _step = _Step.gender);
  }

  Future<void> _onFinish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final nickname = _nicknameController.text.trim();
    final formattedDate =
        "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";

    final error = await DatabaseService().addChild(
      nickname: nickname,
      childBirthdate: formattedDate,
      childGender: _selectedGender!,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      Navigator.pop(context, true);
    } else {
      AppDialog.showError(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
                _buildTopBar(),
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
                      Expanded(child: _buildPrompt()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildStepBody()),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _currentNextAction(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorTheme.goldenYellow,
                          disabledBackgroundColor: ColorTheme.goldenYellow
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0xFF3A4F6E),
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: ColorTheme.warmBrown,
                                ),
                              )
                            : Text(
                                _step == _Step.gender ? 'FINISH' : 'NEXT',
                                style: const TextStyle(
                                  fontFamily: Fonts.fredoka,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ColorTheme.warmBrown,
                                ),
                              ),
                      ),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _saving ? null : _goBack,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: ColorTheme.cream,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ColorTheme.goldenYellow,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    final String nickname = _nicknameController.text.trim().isEmpty
        ? 'your child'
        : _nicknameController.text.trim();

    late final String text;
    switch (_step) {
      case _Step.nickname:
        text = "Who's joining the adventure? Enter their nickname!";
        break;
      case _Step.birthdate:
        text = "When is $nickname's birthday?";
        break;
      case _Step.gender:
        text = "What is $nickname's gender?";
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        color: ColorTheme.cream,
        fontSize: 18,
        fontFamily: Fonts.fredoka,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  VoidCallback? _currentNextAction() {
    switch (_step) {
      case _Step.nickname:
        return _onNicknameNext;
      case _Step.birthdate:
        return _selectedDate != null ? _onBirthdateNext : null;
      case _Step.gender:
        return _selectedGender != null ? _onFinish : null;
    }
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _Step.nickname:
        return _buildNicknameStep();
      case _Step.birthdate:
        return _buildBirthdateStep();
      case _Step.gender:
        return _buildGenderStep();
    }
  }

  Widget _buildNicknameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ColorTheme.cream.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: ColorTheme.cream.withValues(alpha: 0.4),
              ),
            ),
            child: TextField(
              controller: _nicknameController,
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: ColorTheme.cream,
                fontFamily: Fonts.fredoka,
              ),
              decoration: const InputDecoration(
                hintText: "Child's nickname",
                hintStyle: TextStyle(
                  color: ColorTheme.cream,
                  fontFamily: Fonts.fredoka,
                  fontSize: 14,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 20),
            child: Text(
              'Keep it short! Up to 10 characters and no spaces.',
              style: TextStyle(
                color: ColorTheme.cream,
                fontSize: 12,
                fontFamily: Fonts.fredoka,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdateStep() {
    return Padding(
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
                        : ColorTheme.goldenYellow.withValues(alpha: 0.6),
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
                          : ColorTheme.cream.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return Padding(
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
                  onTap: () => setState(() => _selectedGender = gender),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ColorTheme.goldenYellow.withValues(alpha: 0.35)
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
                          Icons.person_rounded,
                          color: isSelected
                              ? ColorTheme.goldenYellow
                              : ColorTheme.goldenYellow.withValues(alpha: 0.6),
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
                                : ColorTheme.cream.withValues(alpha: 0.75),
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
    );
  }
}
