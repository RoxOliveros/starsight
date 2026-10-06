import 'package:StarSight/ui_layer/child_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_signin.dart';
import 'add_child_screen.dart';
import 'app_dialog.dart';
import 'avatar_picker_dialog.dart';
import '../business_layer/orientation_service.dart';
import '../business_layer/database_service.dart';
import '../business_layer/screen_time_service.dart';
import 'screen_time_screen.dart';
import 'account_settings_screen.dart';
import 'music_sounds_screen.dart';
import 'download_analysis_screen.dart';
import 'about_us_screen.dart';
import 'help_center_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color brown = Color(0xFF6F6764);
  // New colors to match the "Parent's Area" mock.
  static const Color cardYellow = Color(0x80F6CE66); // Your Children card bg
  static const Color teal = Color(0xFF54BDB8); // Support section accent
  static const Color mutedGrey = Color(0xFFB9B2A9); // Privacy / Terms links
  // "Parent's Area" title palette (cycled letter by letter).
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

/// A child's age derived from their stored birthdate.
class ChildAge {
  final int years;
  final int months;

  /// False when only a birth year is on file, so months can't be trusted.
  final bool monthsKnown;

  const ChildAge({
    required this.years,
    required this.months,
    this.monthsKnown = true,
  });

  /// Fractional years, e.g. 3.5 for 3 years 6 months.
  double get inYears => years + months / 12;

  String get label {
    if (years == 0) {
      return months == 0 ? 'Less than 1 month old' : '$months mo old';
    }
    if (!monthsKnown || months == 0) {
      return '$years ${years == 1 ? 'year' : 'years'} old';
    }
    return '$years yr $months mo old';
  }
}

ChildAge? childAgeFromBirthdate(String? raw, {DateTime? now}) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  final today = now ?? DateTime.now();

  if (RegExp(r'^\d{4}$').hasMatch(s)) {
    final years = today.year - int.parse(s);
    if (years < 0) return null;
    return ChildAge(years: years, months: 0, monthsKnown: false);
  }

  DateTime? birth = DateTime.tryParse(s);
  if (birth == null) {
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(s);
    if (m != null) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        birth = DateTime(int.parse(m.group(3)!), month, day);
      }
    }
  }
  if (birth == null) return null;

  var years = today.year - birth.year;
  var months = today.month - birth.month;
  if (today.day < birth.day) months--;
  if (months < 0) {
    years--;
    months += 12;
  }
  if (years < 0) return null; // birthdate in the future
  return ChildAge(years: years, months: months);
}

class ChildProfile {
  final String id; // Firestore doc ID — currently the nickname itself
  final String name;
  final String? birthdate; // raw string as saved at sign-up / add-child
  final List<String> goals;
  final String avatarPath;
  final double progress; // 0.0 - 1.0 — not tracked yet, defaults to 0
  final Duration screenTimeToday; // not tracked yet, defaults to 0

  const ChildProfile({
    required this.id,
    required this.name,
    this.birthdate,
    this.goals = const [],
    this.avatarPath = kDefaultAvatarPath,
    this.progress = 0.0,
    this.screenTimeToday = Duration.zero,
  });

  /// Age calculated from [birthdate]; null if it's missing or unreadable.
  ChildAge? get age => childAgeFromBirthdate(birthdate);

  factory ChildProfile.fromMap(
    String id,
    Map<String, dynamic> data, {
    String fallbackAvatarPath = kDefaultAvatarPath,
  }) {
    return ChildProfile(
      id: id,
      name: (data['nickname'] as String?)?.trim().isNotEmpty == true
          ? data['nickname'] as String
          : id,
      birthdate: data['birthdate'] as String?,
      goals: (data['goals'] as List?)?.cast<String>() ?? const [],
      // No per-child avatarPath field in Firestore yet, so this falls back
      // to the real avatar the account picked in AvatarPickerDialog
      // (stored locally per uid via AvatarStorage) rather than a generic
      // default. Once you add a per-child avatarPath field, that will take
      // priority automatically.
      avatarPath: (data['avatarPath'] as String?) ?? fallbackAvatarPath,
      progress: ((data['progress'] as num?) ?? 0.0).toDouble().clamp(0.0, 1.0),
      screenTimeToday: Duration(
        minutes: (data['screenTimeMinutesToday'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class ParentsAreaScreen extends StatefulWidget {
  final String? activeNickname;

  const ParentsAreaScreen({super.key, this.activeNickname});

  @override
  State<ParentsAreaScreen> createState() => _ParentsAreaScreenState();
}

class _ParentsAreaScreenState extends State<ParentsAreaScreen> {
  String _appVersion = '';

  List<ChildProfile> _children = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;
  bool _isLoggingOut = false;
  // Daily limit (minutes) of the selected child; 0 = Off. Loaded from
  // Firestore, so this default is only shown until that finishes.
  int _screenTimeLimit = DatabaseService.defaultScreenTimeLimitMinutes;
  bool _autoBackup = false; // automatic backup toggle (UI only)

  ChildProfile? get _selectedChild =>
      _children.isEmpty ? null : _children[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    OrientationService.setPortrait();
    // Time spent in the Parent's Area shouldn't count as the child's play time.
    ScreenTimeService.instance.pause();
    _loadChildren();
  }

  @override
  void dispose() {
    if (!_isLoggingOut) {
      OrientationService.setLandscape();
    }

    ScreenTimeService.instance.resume();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'StarSight v${info.version}';
      });
    }
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _loading = false;
        _error = "You're not signed in.";
      });
      return;
    }

    try {
      final rawChildren = await DatabaseService().getChildren();
      // The one real avatar this account has actually selected (see
      // AvatarStorage in avatar_picker_dialog.dart) — used as the fallback
      // for any child without its own avatarPath field in Firestore.
      final accountAvatarPath = await AvatarStorage.getSelectedAvatarPath();

      final children = rawChildren
          .map(
            (data) => ChildProfile.fromMap(
              data['id'] as String,
              data,
              fallbackAvatarPath: accountAvatarPath,
            ),
          )
          .toList();

      final activeIndex = children.indexWhere(
        (c) => c.id == widget.activeNickname,
      );

      if (!mounted) return;
      setState(() {
        _children = children;
        _selectedIndex = activeIndex >= 0 ? activeIndex : 0;
        _loading = false;
      });
      await _loadScreenTimeLimit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load your children. Pull down to try again.";
      });
    }
  }

  /// Reads the selected child's saved daily limit (0 = Off) into the dropdown.
  Future<void> _loadScreenTimeLimit() async {
    final id = _selectedChild?.id;
    if (id == null) return;

    final data = await DatabaseService().getScreenTime(id);
    if (!mounted || id != _selectedChild?.id) return; // child changed meanwhile

    setState(() {
      _screenTimeLimit =
          DatabaseService.screenTimeLimitOptions.contains(data.limitMinutes)
          ? data.limitMinutes
          : DatabaseService.defaultScreenTimeLimitMinutes;
    });
  }

  /// Saves the dropdown choice for the selected child and applies it live.
  Future<void> _setScreenTimeLimit(int minutes) async {
    final id = _selectedChild?.id;
    if (id == null) return;

    final previous = _screenTimeLimit;
    setState(() => _screenTimeLimit = minutes);

    final ok = await DatabaseService().setScreenTimeLimit(id, minutes);
    if (!mounted) return;

    if (ok) {
      // Applies immediately if this child is the one currently playing.
      ScreenTimeService.instance.updateLimit(id, minutes);
    } else if (id == _selectedChild?.id) {
      setState(() => _screenTimeLimit = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.of(context).viewPadding.bottom,
          ),
          content: const Text("Couldn't save. Please try again."),
        ),
      );
    }
  }

  Future<void> _addChild() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    );
    if (added == true) _loadChildren();
  }

  Future<void> _openMenuItem(String label) async {
    switch (label) {
      case 'Child\'s Area':
        if (_selectedChild != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisReportsScreen(
                child: _selectedChild,
                isFromParentsArea: true,
              ),
            ),
          );

          // Refresh Grownup's Area when returning from Child's Area.
          if (mounted) {
            await _loadChildren();
          }
        }
        break;
      case 'Game Time':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ScreenTimeScreen(initialChildId: _selectedChild?.id),
          ),
        );
        break;

      case 'Account Settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
        );
        break;

      case 'Music and Sounds':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MusicSoundsScreen()),
        );
        break;

      case 'Download Analysis':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DownloadAnalysisScreen(
              childName: _selectedChild?.name ?? 'Child Name',
            ),
          ),
        );
        break;

      case 'About Us':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutUsScreen()),
        );
        break;

      case 'Help Center':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label — coming soon')));
    }
  }

  Future<void> _logOut() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      message: "Are you sure you want to log out?",
      confirmLabel: "Log Out",
      cancelLabel: "Cancel",
    );

    if (!confirmed) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    _isLoggingOut = true;

    OrientationService.setPortrait();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignUpSignInScreen()),
      (route) => false,
    );
  }

  Future<void> _switchChild(int index) async {
    if (index == _selectedIndex) return; // already selected

    final child = _children[index];
    const accent = ColorTheme.orange;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
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
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: accent,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'Switch to ${child.name}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: ColorTheme.deepNavyBlue,
                ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                'Are you sure you want to switch to ${child.name}? '
                'The reports and settings shown here will be for '
                '${child.name}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: ColorTheme.brown,
                ),
              ),
              const SizedBox(height: 20),

              // Confirm
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'YES, SWITCH',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: ColorTheme.brown,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: ColorTheme.brown,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _selectedIndex = index);
      _loadScreenTimeLimit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _selectedChild?.id);
      },
      child: Scaffold(
        backgroundColor: ColorTheme.cream,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadChildren,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        // ListView (not a Column) so pull-to-refresh still works on error.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        children: [
          Icon(Icons.error_outline_rounded, color: ColorTheme.brown, size: 40),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.fredoka,
              color: ColorTheme.brown,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildRainbowTitle("GROWNUP'S AREA")),
          const SizedBox(height: 25),
          _buildYourChildrenCard(),
          const SizedBox(height: 27),
          _buildSectionTitle('SETTINGS', ColorTheme.orange),
          const SizedBox(height: 15),
          _buildOutlinedMenuCard(
            borderColor: ColorTheme.orange,
            iconColor: ColorTheme.orange,
            rows: [
              _MenuRowData(
                icon: Icons.person_outline_rounded,
                label: 'Account',
                onTap: () => _openMenuItem('Account Settings'),
              ),

              _MenuRowData(
                icon: Icons.music_note_rounded,
                label: 'Music and Sounds',
                onTap: () => _openMenuItem('Music and Sounds'),
              ),
            ],
          ),
          const SizedBox(height: 27),
          _buildSectionTitle('BACKUP', ColorTheme.teal),
          const SizedBox(height: 15),
          _buildOutlinedMenuCard(
            borderColor: ColorTheme.teal,
            iconColor: ColorTheme.teal,
            topWidget: _AutoBackupRow(
              value: _autoBackup,
              onChanged: (v) => setState(() => _autoBackup = v),
            ),
            rows: [
              _MenuRowData(
                icon: Icons.download_rounded,
                label: 'Download Analysis',
                onTap: () => _openMenuItem('Download Analysis'),
              ),
            ],
          ),
          const SizedBox(height: 27),
          _buildSectionTitle('SUPPORT', ColorTheme.yellow),
          const SizedBox(height: 15),
          _buildOutlinedMenuCard(
            borderColor: ColorTheme.yellow,
            iconColor: ColorTheme.yellow,
            rows: [
              _MenuRowData(
                icon: Icons.info_outline_rounded,
                label: 'About Us',
                onTap: () => _openMenuItem('About Us'),
              ),
              _MenuRowData(
                icon: Icons.help_outline_rounded,
                label: 'Help Center',
                onTap: () => _openMenuItem('Help Center'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openMenuItem('Privacy & Data'),
              style: TextButton.styleFrom(
                foregroundColor: ColorTheme.mutedGrey,
              ),
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openMenuItem('Terms of Use'),
              style: TextButton.styleFrom(
                foregroundColor: ColorTheme.mutedGrey,
              ),
              child: const Text(
                'Terms of Use',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _logOut,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _appVersion.isEmpty ? 'StarSight' : _appVersion,
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 12,
                color: ColorTheme.mutedGrey.withValues(alpha: 0.9),
              ),
            ),
          ),
          Center(
            child: Text(
              'IntelliStar™',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 12,
                color: ColorTheme.mutedGrey.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ColorTheme.deepNavyBlue,
          ),

          onPressed: () =>
              Navigator.pop(context, _selectedChild?.id), // was .name
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
    int letterIndex = 0; // counts only non-space characters
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = ColorTheme.brown; // space, doesn't consume a color slot
      } else {
        final pairIndex = letterIndex ~/ 2; // 0,0,1,1,2,2,...
        color = palette[pairIndex % palette.length];
        letterIndex++;
      }
      spans.add(
        TextSpan(
          text: char,
          style: TextStyle(color: color),
        ),
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: AppTextStyles.fredoka,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }

  Widget _buildYourChildrenCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: ColorTheme.cardYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR CHILDREN',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ColorTheme.deepNavyBlue,
            ),
          ),
          const SizedBox(height: 15),
          if (_children.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildEmptyChildrenNote(),
            )
          else
            _buildChildrenRow(),
          const SizedBox(height: 15),

          _CardMenuRow(
            icon: Icons.assessment_rounded,
            label: 'Child\'s Area',
            iconColor: ColorTheme.deepNavyBlue,
            labelColor: ColorTheme.deepNavyBlue,

            onTap: () => _openMenuItem('Child\'s Area'),
          ),

          const SizedBox(height: 5),

          Divider(color: ColorTheme.brown.withValues(alpha: 0.18), height: 1),

          const SizedBox(height: 5),

          // _CardMenuRow(
          //   icon: Icons.hourglass_bottom_rounded,
          //   label: 'Screen Time',
          //   iconColor: ColorTheme.deepNavyBlue,
          //   labelColor: ColorTheme.deepNavyBlue,
          //
          //   onTap: () => _openMenuItem('Screen Time'),
          // ),
          _ScreenTimeDropdownRow(
            value: _screenTimeLimit,
            options: DatabaseService.screenTimeLimitOptions,
            onChanged: _setScreenTimeLimit,
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEmptyChildrenNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        "You haven't added a child yet. Tap the + circle to get started.",
        style: TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: 13,
          color: ColorTheme.brown,
        ),
      ),
    );
  }

  Widget _buildChildrenRow() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _children.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == _children.length) {
            return _AddChildCircle(onTap: _addChild);
          }
          final child = _children[index];
          final selected = index == _selectedIndex;
          return _ChildAvatarCircle(
            child: child,
            selected: selected,
            onTap: () => _switchChild(
              index,
            ), // was: setState(() => _selectedIndex = index)
          );
        },
      ),
    );
  }

  Widget _buildOutlinedMenuCard({
    required Color borderColor,
    required Color iconColor,
    required List<_MenuRowData> rows,
    Widget? topWidget, // optional custom row shown above the rows
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ColorTheme.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: Column(
        children: [
          if (topWidget != null) ...[
            topWidget,
            Divider(color: borderColor.withValues(alpha: 0.25), height: 1),
          ],
          for (int i = 0; i < rows.length; i++) ...[
            _CardMenuRow(
              icon: rows[i].icon,
              label: rows[i].label,
              iconColor: iconColor,
              labelColor: ColorTheme.deepNavyBlue,
              onTap: rows[i].onTap,
            ),
            if (i != rows.length - 1)
              Divider(color: borderColor.withValues(alpha: 0.25), height: 1),
          ],
        ],
      ),
    );
  }
}

class _MenuRowData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuRowData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _CardMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _CardMenuRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: labelColor.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildAvatarCircle extends StatelessWidget {
  final ChildProfile child;
  final bool selected;
  final VoidCallback onTap;

  const _ChildAvatarCircle({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
              border: Border.all(
                color: selected ? ColorTheme.orange : Colors.transparent,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                child.avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Image.asset(kDefaultAvatarPath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              child.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? ColorTheme.orange : ColorTheme.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChildCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChildCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
              border: Border.all(
                color: ColorTheme.brown.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: ColorTheme.brown,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(
            width: 68,
            child: Text(
              'Add Child',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ColorTheme.brown,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenTimeDropdownRow extends StatelessWidget {
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _ScreenTimeDropdownRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  String _label(int m) => m == 0 ? 'Off' : '$m min';

  @override
  Widget build(BuildContext context) {
    final isOff = value == 0;
    final accent = isOff ? ColorTheme.mutedGrey : ColorTheme.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 20,
            color: ColorTheme.deepNavyBlue,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Game Time',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorTheme.deepNavyBlue,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent, width: 2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isDense: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: Colors.white,
                icon: Icon(Icons.arrow_drop_down_rounded, color: accent),
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
                items: [
                  for (final m in options)
                    DropdownMenuItem<int>(
                      value: m,
                      child: Text(
                        _label(m),
                        style: TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontWeight: FontWeight.w700,
                          color: m == 0
                              ? ColorTheme.mutedGrey
                              : ColorTheme.brown,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoBackupRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AutoBackupRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = value ? ColorTheme.teal : ColorTheme.mutedGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_rounded, size: 20, color: ColorTheme.teal),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Automatic Backup',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorTheme.deepNavyBlue,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: ColorTheme.mutedGrey,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
