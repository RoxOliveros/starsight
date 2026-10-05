import 'package:flutter/material.dart';
import '../business_layer/database_service.dart';
import 'parents_area_screen.dart'; // ColorTheme / AppTextStyles (same as analysis_reports_screen.dart)
import 'avatar_picker_dialog.dart'; // kDefaultAvatarPath, AvatarStorage, AvatarPickerDialog

/// What happened on the Edit Profile screen.
enum EditChildResult { none, saved, deleted }

/// Lets a grown-up edit a child's nickname, birthday, gender and avatar,
/// or delete the child.
///
/// The Firestore document ID (childId) never changes, so progress, screen
/// time and avatar stay attached. Pops with an [EditChildResult].
class EditChildScreen extends StatefulWidget {
  final String childId;
  final String initialNickname;
  final DateTime? initialBirthdate;
  final String? initialGender; // "Boy" / "Girl"
  final String? avatarPath; // current avatar of this child

  const EditChildScreen({
    super.key,
    required this.childId,
    required this.initialNickname,
    this.initialBirthdate,
    this.initialGender,
    this.avatarPath,
  });

  /// Convenience: opens the screen and returns what happened.
  static Future<EditChildResult> open(
      BuildContext context, {
        required String childId,
        required String initialNickname,
        DateTime? initialBirthdate,
        String? initialGender,
        String? avatarPath,
      }) async {
    final result = await Navigator.push<EditChildResult>(
      context,
      MaterialPageRoute(
        builder: (_) => EditChildScreen(
          childId: childId,
          initialNickname: initialNickname,
          initialBirthdate: initialBirthdate,
          initialGender: initialGender,
          avatarPath: avatarPath,
        ),
      ),
    );
    return result ?? EditChildResult.none;
  }

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  static const String _girlAsset = 'assets/images/girl.png';
  static const String _boyAsset = 'assets/images/boy.png';
  static const Color _danger = Color(0xFFD64545);

  late final TextEditingController _nameCtrl;
  late final String _initialAvatarPath;
  late String _avatarPath;
  DateTime? _birthdate;
  String? _gender;
  bool _saving = false;
  bool _didSave = false; // true once details reached Firestore
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialNickname);
    _birthdate = widget.initialBirthdate;
    _gender = widget.initialGender;
    _initialAvatarPath = widget.avatarPath ?? kDefaultAvatarPath;
    _avatarPath = _initialAvatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Logic ────────────────────────────────────────────────────────────

  bool get _hasChanges {
    final b = widget.initialBirthdate;
    final sameDate = (b == null && _birthdate == null) ||
        (b != null &&
            _birthdate != null &&
            b.year == _birthdate!.year &&
            b.month == _birthdate!.month &&
            b.day == _birthdate!.day);
    return _nameCtrl.text.trim() != widget.initialNickname.trim() ||
        !sameDate ||
        _gender != widget.initialGender ||
        _avatarPath != _initialAvatarPath;
  }

  String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _ageText(DateTime b) {
    final now = DateTime.now();
    int years = now.year - b.year;
    int months = now.month - b.month;
    if (now.day < b.day) months--;
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years <= 0) return '$months month${months == 1 ? '' : 's'} old';
    if (months == 0) return '$years year${years == 1 ? '' : 's'} old';
    return '$years yr $months mo old';
  }

  Future<void> _changeAvatar() async {
    FocusScope.of(context).unfocus();
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => AvatarPickerDialog(selectedAssetPath: _avatarPath),
    );
    if (picked != null && mounted) {
      setState(() => _avatarPath = picked);
    }
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final firstDate = DateTime(2000); // same as sign-up
    var initial = _birthdate ?? now.subtract(const Duration(days: 365 * 5));
    if (initial.isBefore(firstDate)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
      builder: _datePickerBuilder,
    );
    if (picked != null) {
      setState(() {
        _birthdate = picked;
        _error = null;
      });
    }
  }

  /// Same look as the sign-up birthdate picker.
  Widget _datePickerBuilder(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: const ColorScheme.light(
          primary: ColorTheme.titleGold,
          onPrimary: ColorTheme.brown,
          surface: ColorTheme.cream,
          onSurface: ColorTheme.brown,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: ColorTheme.cream,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shadowColor: const Color(0xFF3A4F6E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          headerBackgroundColor: ColorTheme.deepNavyBlue,
          headerForegroundColor: ColorTheme.cream,
          headerHeadlineStyle: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
          headerHelpStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          weekdayStyle: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorTheme.deepNavyBlue,
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
              return ColorTheme.brown.withValues(alpha: 0.3);
            }
            return ColorTheme.brown;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return ColorTheme.titleGold;
            }
            return Colors.transparent;
          }),
          dayOverlayColor: WidgetStateProperty.all(
            ColorTheme.titleGold.withValues(alpha: 0.25),
          ),
          todayForegroundColor: WidgetStateProperty.all(ColorTheme.brown),
          todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
          todayBorder: const BorderSide(
            color: ColorTheme.titleGold,
            width: 2,
          ),
          yearForegroundColor: WidgetStateProperty.all(ColorTheme.brown),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return ColorTheme.titleGold;
            }
            return Colors.transparent;
          }),
          yearOverlayColor: WidgetStateProperty.all(
            ColorTheme.titleGold.withValues(alpha: 0.25),
          ),
          dividerColor: ColorTheme.deepNavyBlue.withValues(alpha: 0.2),
          cancelButtonStyle: TextButton.styleFrom(
            foregroundColor: ColorTheme.deepNavyBlue,
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          confirmButtonStyle: TextButton.styleFrom(
            foregroundColor: ColorTheme.brown,
            backgroundColor: ColorTheme.titleGold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: base.textTheme.copyWith(
          titleSmall: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorTheme.brown,
          ),
        ),
        iconTheme: const IconThemeData(color: ColorTheme.deepNavyBlue),
      ),
      child: child!,
    );
  }

  /// Shows the message in the banner above the Save button.
  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  Future<void> _save() async {
    // ── Nickname rules (same as the sign-up nickname screen) ──────────
    final nickname = _nameCtrl.text.trim();
    if (nickname.isEmpty) {
      _fail('Nickname should not be empty');
      return;
    }
    if (RegExp(r'[0-9]').hasMatch(nickname)) {
      _fail('Nicknames cannot contain numbers. Letters only, please!');
      return;
    }
    if (nickname.contains(' ')) {
      _fail('Nickname should not contain any spaces');
      return;
    }

    // ── Birthday + gender required ────────────────────────────────────
    if (_birthdate == null) {
      _fail('Please choose a birthday.');
      return;
    }
    if (_gender == null) {
      _fail('Please choose Boy or Girl.');
      return;
    }

    if (!_hasChanges) {
      Navigator.pop(
        context,
        _didSave ? EditChildResult.saved : EditChildResult.none,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final db = DatabaseService();

    // ── Birthdate rules (same as the sign-up birthdate screen) ────────
    // Checked BEFORE the confirmation, so the grown-up isn't asked
    // "are you sure?" about something that is going to be rejected.
    final parentBirthYear =
        int.tryParse(await db.getParentBirthYear() ?? '') ?? 0;
    if (!mounted) return;

    final childYear = _birthdate!.year;
    final childAge = DateTime.now().year - childYear;
    final ageDifference = childYear - parentBirthYear;

    if (childAge < 3) {
      _fail('The child must be at least 3 years old to register.');
      return;
    }
    if (ageDifference < 18) {
      _fail(
        'Invalid birthdate. The Grownup must be at least 18 years older than the child.',
      );
      return;
    }

    // ── "Are you sure you want to save?" ──────────────────────────────
    final confirmed = await _showConfirmDialog(
      icon: Icons.save_rounded,
      accent: ColorTheme.teal,
      title: 'Save changes?',
      message: "Are you sure you want to save these changes to "
          "$nickname's profile?",
      confirmLabel: 'Yes, save',
      cancelLabel: 'Not yet',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // ── Save details ──────────────────────────────────────────────────
    final b = _birthdate!;
    final error = await db.updateChildInfo(
      childId: widget.childId,
      nickname: nickname,
      birthdate: '${b.month}/${b.day}/${b.year}', // same format as sign-up
      gender: _gender!,
    );
    if (!mounted) return;
    if (error != null) {
      _fail(error);
      return;
    }
    _didSave = true; // details are already in Firestore

    // ── Save avatar (only if it changed) ──────────────────────────────
    if (_avatarPath != _initialAvatarPath) {
      final avatarError = await db.updateChildAvatar(
        childId: widget.childId,
        avatarPath: _avatarPath,
      );
      if (!mounted) return;
      if (avatarError != null) {
        _fail(avatarError);
        return;
      }

      // The account-level avatar is what other screens fall back to, so
      // keep it in sync when this is the child currently selected.
      final activeChildId = await db.getNickname();
      if (activeChildId == widget.childId) {
        await AvatarStorage.setSelectedAvatarPath(_avatarPath);
      }
      if (!mounted) return;
    }

    Navigator.pop(context, EditChildResult.saved);
  }

  Future<void> _deleteChild() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final db = DatabaseService();

    // Check first, so the grown-up isn't shown a scary warning that
    // then fails.
    final children = await db.getChildren();
    if (!mounted) return;
    if (children.length <= 1) {
      _fail("You can't delete the only child profile. Add another child first.");
      return;
    }

    final name = widget.initialNickname;
    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_forever_rounded,
      accent: _danger,
      title: 'Delete $name?',
      message: "Are you sure you want to delete $name's profile?",
      warningTitle: 'PLEASE READ BEFORE YOU CONTINUE',
      warnings: [
        'This cannot be undone.',
        "All of $name's learning progress and game history will be permanently erased.",
        'Analysis reports and screen time records for $name will be lost.',
        "$name's avatar and profile details will be removed from your account.",
        'Deleted data cannot be recovered.',
      ],
      confirmLabel: 'Delete forever',
      cancelLabel: 'Keep profile',
      emphasizeCancel: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await db.deleteChild(widget.childId);
    if (!mounted) return;
    if (error != null) {
      _fail(error);
      return;
    }

    Navigator.pop(context, EditChildResult.deleted);
  }

  /// Shared dialog for "discard?", "save?" and "delete?".
  /// Returns true when the confirm button is pressed.
  Future<bool> _showConfirmDialog({
    required IconData icon,
    required Color accent,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    String? warningTitle,
    List<String> warnings = const [],

    /// For dangerous actions: the safe button is the big filled one and
    /// the dangerous one is a quieter outline.
    bool emphasizeCancel = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final confirmButton = SizedBox(
          width: double.infinity,
          height: 48,
          child: emphasizeCancel
              ? OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent, width: 2),
              shape: const StadiumBorder(),
            ),
            child: _dialogButtonText(confirmLabel, accent),
          )
              : ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: _dialogButtonText(confirmLabel, Colors.white),
          ),
        );

        final cancelButton = SizedBox(
          width: double.infinity,
          height: 48,
          child: emphasizeCancel
              ? ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorTheme.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: _dialogButtonText(cancelLabel, Colors.white),
          )
              : TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: ColorTheme.brown,
              shape: const StadiumBorder(),
            ),
            child: _dialogButtonText(cancelLabel, ColorTheme.brown),
          ),
        );

        return Dialog(
          backgroundColor: ColorTheme.cream,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: accent.withValues(alpha: 0.5), width: 3),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 34),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: accent == _danger
                        ? _danger
                        : ColorTheme.deepNavyBlue,
                  ),
                ),
                const SizedBox(height: 10),

                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: ColorTheme.brown,
                  ),
                ),

                // Warning box
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE1CB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (warningTitle != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  warningTitle,
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        for (final w in warnings)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    w,
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                      color: ColorTheme.brown,
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

                const SizedBox(height: 20),

                // Buttons: the safe choice is always on top for delete
                if (emphasizeCancel) ...[
                  cancelButton,
                  const SizedBox(height: 8),
                  confirmButton,
                ] else ...[
                  confirmButton,
                  const SizedBox(height: 4),
                  cancelButton,
                ],
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Widget _dialogButtonText(String text, Color color) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: AppTextStyles.fredoka,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: color,
    ),
  );

  /// "Discard changes?" dialog, same look as the other dialogs.
  Future<bool> _confirmDiscard() async {
    if (!_hasChanges || _saving) return true;
    return _showConfirmDialog(
      icon: Icons.edit_note_rounded,
      accent: ColorTheme.orange,
      title: 'Discard changes?',
      message: 'Your edits have not been saved yet. '
          'If you leave now, they will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.pop(
        context,
        _didSave ? EditChildResult.saved : EditChildResult.none,
      );
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: ColorTheme.cream,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: ColorTheme.deepNavyBlue,
                    ),
                    onPressed: _handleBack,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _buildRainbowTitle('EDIT PROFILE')),
                      const SizedBox(height: 24),
                      _buildForm(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(_error!),
                      ],
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                      const SizedBox(height: 14),
                      _buildDeleteButton(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRainbowTitle(String text) {
    const palette = [
      ColorTheme.titleSky,
      ColorTheme.titleGold,
      ColorTheme.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = ColorTheme.brown;
      } else {
        final pairIndex = letterIndex ~/ 2;
        color = palette[pairIndex % palette.length];
        letterIndex++;
      }
      spans.add(TextSpan(text: char, style: TextStyle(color: color)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  /// Avatar on top, then nickname, birthday, gender.
  /// No card background any more: the fields sit directly on the cream page.
  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarSection(),
          const SizedBox(height: 26),

          // Nickname
          _label('NICKNAME'),
          TextField(
            controller: _nameCtrl,
            maxLength: 10, // same limit as sign-up
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            style: _fieldTextStyle,
            decoration: _fieldDecoration(hint: "Child's nickname").copyWith(
              counterText: '',
              suffixText: '${_nameCtrl.text.length}/10',
              suffixStyle: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorTheme.brown.withValues(alpha: 0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'Letters only, no spaces.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: ColorTheme.brown.withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Birthday
          _label('BIRTHDAY'),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _fieldDecoration().copyWith(
                suffixIcon: const Icon(
                  Icons.calendar_month_rounded,
                  size: 22,
                  color: ColorTheme.deepNavyBlue,
                ),
              ),
              child: Text(
                _birthdate == null ? 'Select date' : _formatDate(_birthdate!),
                style: _fieldTextStyle.copyWith(
                  color: _birthdate == null
                      ? ColorTheme.brown.withValues(alpha: 0.5)
                      : ColorTheme.brown,
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Gender
          _label('GENDER'),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: _genderTile('Girl', _girlAsset, Icons.girl_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _genderTile('Boy', _boyAsset, Icons.boy_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _saving ? null : _changeAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: ColorTheme.orange, width: 5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _avatarPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Icon(
                        Icons.face_rounded,
                        color: ColorTheme.deepNavyBlue,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: ColorTheme.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _saving ? null : _changeAvatar,
            child: const Text(
              'TAP TO CHANGE AVATAR',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorTheme.deepNavyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Picture tile with the label underneath, like the reference design.
  Widget _genderTile(String value, String asset, IconData fallbackIcon) {
    final selected = _gender == value;

    return GestureDetector(
      onTap: () => setState(() {
        _gender = value;
        _error = null;
      }),
      child: AnimatedScale(
        scale: selected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        // Solid white so the tile still reads well on cream.
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: selected
                              ? ColorTheme.orange
                              : ColorTheme.orange.withValues(alpha: 0.25),
                          width: 3.5,
                        ),
                        boxShadow: selected
                            ? [
                          BoxShadow(
                            color: ColorTheme.orange
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : null,
                      ),
                      child: Opacity(
                        opacity: selected ? 1 : 0.8,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Icon(
                            fallbackIcon,
                            size: 56,
                            color: ColorTheme.deepNavyBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: ColorTheme.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? ColorTheme.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: selected ? Colors.white : ColorTheme.deepNavyBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE1CB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ColorTheme.orange,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ColorTheme.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTheme.teal,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: ColorTheme.teal.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'SAVE CHANGES',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _saving ? null : _deleteChild,
        icon: const Icon(Icons.delete_outline_rounded, size: 22),
        label: const Text(
          'DELETE CHILD PROFILE',
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          side: const BorderSide(color: _danger, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
      ),
    );
  }

  // ── Small helpers ────────────────────────────────────────────────────

  static const TextStyle _fieldTextStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: ColorTheme.brown,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTextStyles.fredoka,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: ColorTheme.deepNavyBlue,
      ),
    ),
  );

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w700,
      color: ColorTheme.brown.withValues(alpha: 0.4),
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColorTheme.orange, width: 2.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
      const BorderSide(color: ColorTheme.deepNavyBlue, width: 2.5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColorTheme.orange, width: 2.5),
    ),
  );
}