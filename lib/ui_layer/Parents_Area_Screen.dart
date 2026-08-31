import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'signup_signin.dart';
import 'behavior_reports_screen.dart';
import 'app_dialog.dart';
import 'avatar_picker_dialog.dart'; // for kDefaultAvatarPath
import '../business_layer/orientation_service.dart';
import '../business_layer/database_service.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color brown = Color(0xFF6F6764);
  // New colors to match the "Parent's Area" mock.
  static const Color cardYellow = Color(0x80F6CE66);// Your Children card bg
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

/// Data model for a child profile shown in the Parent's Area.
///
/// Maps to `users/{uid}/children/{nickname}` in Firestore. Today that
/// document only has `nickname`, `goals`, and `createdAt` — there's no
/// `avatarPath`, `progress`, or screen-time field yet, so those fall back
/// to placeholders below until you add per-child fields for them (see the
/// notes next to `getChildren()` in DatabaseService).
class ChildProfile {
  final String id; // Firestore doc ID — currently the nickname itself
  final String name;
  final List<String> goals;
  final String avatarPath;
  final double progress; // 0.0 - 1.0 — not tracked yet, defaults to 0
  final Duration screenTimeToday; // not tracked yet, defaults to 0

  const ChildProfile({
    required this.id,
    required this.name,
    this.goals = const [],
    this.avatarPath = kDefaultAvatarPath,
    this.progress = 0.0,
    this.screenTimeToday = Duration.zero,
  });

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
  const ParentsAreaScreen({super.key});

  @override
  State<ParentsAreaScreen> createState() => _ParentsAreaScreenState();
}

class _ParentsAreaScreenState extends State<ParentsAreaScreen> {
  List<ChildProfile> _children = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  ChildProfile? get _selectedChild =>
      _children.isEmpty ? null : _children[_selectedIndex];

  @override
  void initState() {
    super.initState();

    OrientationService.setPortrait();
    _loadChildren();
  }

  @override
  void dispose() {
    // Restore the app's default landscape lock for everything else.
    OrientationService.setLandscape();
    super.dispose();
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
          .map((data) => ChildProfile.fromMap(
        data['id'] as String,
        data,
        fallbackAvatarPath: accountAvatarPath,
      ))
          .toList();

      if (!mounted) return;
      setState(() {
        _children = children;
        _selectedIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load your children. Pull down to try again.";
      });
    }
  }

  Future<void> _addChild() async {
    // TODO: point this to your real "Add Child" flow, e.g.:
    // final added = await Navigator.push<bool>(
    //   context,
    //   MaterialPageRoute(builder: (_) => const AddChildScreen()),
    // );
    // if (added == true) _loadChildren();
  }

  void _openMenuItem(String label) {
    switch (label) {
      case 'Analysis and Reports':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BehaviorReportsScreen()),
        );
        break;
    // TODO: wire the remaining items to their real screens as you build
    // them, e.g. ScreenTimeScreen(), AccountSettingsScreen(),
    // AboutUsScreen(), HelpCenterScreen(), NotificationsScreen(), etc.
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — coming soon')),
        );
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignUpSignInScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Center(child: _buildRainbowTitle("PARENT'S AREA")),
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
                icon: Icons.notifications_none_rounded,
                label: 'Notification',
                onTap: () => _openMenuItem('Notifications'),
              ),

            ],
          ),
          const SizedBox(height: 27),
          _buildSectionTitle('SUPPORT', ColorTheme.teal),
          const SizedBox(height: 15),
          _buildOutlinedMenuCard(
            borderColor: ColorTheme.teal,
            iconColor: ColorTheme.teal,
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
              style: TextButton.styleFrom(foregroundColor: ColorTheme.mutedGrey),
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
              style: TextButton.styleFrom(foregroundColor: ColorTheme.mutedGrey),
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
              'StarSight v1.0.0',
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
    // Just the back button — the "Parent's Area" title lives in the body now.
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ColorTheme.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
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
      spans.add(TextSpan(
        text: char,
        style: TextStyle(color: color),
      ));
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
            label: 'Analysis and Reports',
            iconColor: ColorTheme.deepNavyBlue,
            labelColor: ColorTheme.deepNavyBlue,

            onTap: () => _openMenuItem('Analysis and Reports'),
          ),

          const SizedBox(height: 5),

          Divider(color: ColorTheme.brown.withValues(alpha: 0.18), height: 1),

          const SizedBox(height: 5),
          _CardMenuRow(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Screen Time',
            iconColor: ColorTheme.deepNavyBlue,
            labelColor: ColorTheme.deepNavyBlue,

            onTap: () => _openMenuItem('Screen Time'),
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
            onTap: () => setState(() => _selectedIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildOutlinedMenuCard({
    required Color borderColor,
    required Color iconColor,
    required List<_MenuRowData> rows,
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

/// A single row used inside the yellow "Your Children" card and the
/// outlined Settings / Support cards: icon, label, chevron — no filled
/// icon-circle background, just a thin divider between rows.
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
                errorBuilder: (context, error, stack) => Image.asset(
                  kDefaultAvatarPath,
                  fit: BoxFit.cover,
                ),
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