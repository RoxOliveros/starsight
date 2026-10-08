import 'package:StarSight/business_layer/database_service.dart';
import 'package:StarSight/ui_layer/dashboard.dart';
import 'package:StarSight/ui_layer/parents_pin_validation.dart';
import 'package:flutter/material.dart';
import '../games_ui_layer/audio_helper.dart';
import 'avatar_picker_dialog.dart';
import 'parents_area_screen.dart';
import 'child_profile_screen.dart';
import 'edit_child_screen.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color brown = Color(0xFF6F6764);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
}

class ProfileDayDialog extends StatefulWidget {
  final String childId;
  final String name;
  final VoidCallback? onProfileChanged;

  const ProfileDayDialog({
    super.key,
    required this.childId,
    required this.name,
    this.onProfileChanged,
  });

  @override
  State<ProfileDayDialog> createState() => _ProfileDayDialogState();
}

class _ProfileDayDialogState extends State<ProfileDayDialog> {
  String _avatarPath = kDefaultAvatarPath;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _displayName = widget.name; // shown until the load finishes
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final children = await DatabaseService().getChildren();

    final myChild = children.firstWhere(
          (c) => c['id'] == widget.childId,
      orElse: () => {},
    );

    if (!mounted) return;

    setState(() {
      _avatarPath = (myChild['avatarPath'] as String?) ?? kDefaultAvatarPath;
      if (myChild.isNotEmpty) {
        _displayName = DatabaseService.displayNameOf(myChild);
      }
    });
  }

  Future<void> _openAvatarPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AvatarPickerDialog(selectedAssetPath: _avatarPath),
    );

    if (selected == null) return;

    final error = await DatabaseService().updateChildAvatar(
      childId: widget.childId,
      avatarPath: selected,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _avatarPath = selected);
    widget.onProfileChanged?.call();
  }

  /// Opens the dashboard for whichever child still exists after a delete.
  /// Waits a moment so the previous screens finish popping first, which
  /// avoids the "_debugLocked" navigator assertion.
  Future<void> _goToRemainingChild(NavigatorState navigator) async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!navigator.mounted) return;

    final nextId = await DatabaseService().getNickname();
    if (!navigator.mounted || nextId == null) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(nickname: nextId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE9C679)),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 8),

                // 👤 Profile Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4DEB3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      // 🐻 Tap avatar to open the picker
                      InkWell(
                        onTap: (){
                          SfxHelper.instance.play(Sfx.keyTap);
                          _openAvatarPicker();
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ColorTheme.orange,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(_avatarPath, fit: BoxFit.cover),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          _displayName,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTheme.orange,
                          ),
                        ),
                      ),

                      Image.asset('assets/images/night_star.png', width: 35),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),

                const SizedBox(height: 18),

                // ── Child's Area ─────────────────────────────────────
                _ProfileOption(
                  icon: Icons.auto_awesome,
                  label: "Child's Area",
                  onTap: () async {
                    SfxHelper.instance.play(Sfx.keyTap);
                    final navigator = Navigator.of(context);
                    final childId = widget.childId;
                    final onChanged = widget.onProfileChanged;
                    navigator.pop(); // close the drawer

                    final bool? authenticated = await navigator.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ParentPinValidation(),
                      ),
                    );

                    if (authenticated == true) {
                      final result = await navigator.push<EditChildResult>(
                        MaterialPageRoute(
                          builder: (_) =>
                              AnalysisReportsScreen(childNickname: childId),
                        ),
                      );

                      if (result == EditChildResult.deleted) {
                        await _goToRemainingChild(navigator);
                      } else if (result == EditChildResult.saved) {
                        onChanged?.call(); // refresh dashboard
                      }
                    }
                  },
                ),

                const SizedBox(height: 14),

                // ── Grownup's Area ───────────────────────────────────
                _ProfileOption(
                  icon: Icons.group,
                  label: "Grownup's Area",
                  onTap: () async {
                    SfxHelper.instance.play(Sfx.keyTap);
                    final navigator = Navigator.of(context);
                    final childId = widget.childId;
                    final onChanged = widget.onProfileChanged;
                    navigator.pop(); // close the drawer

                    final bool? authenticated = await navigator.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ParentPinValidation(),
                      ),
                    );

                    if (authenticated == true) {
                      final selectedId = await navigator.push<String>(
                        MaterialPageRoute(
                          builder: (_) =>
                              ParentsAreaScreen(activeNickname: childId),
                        ),
                      );

                      if (selectedId == null) {
                        onChanged?.call();
                        return;
                      }

                      // Was the child we started on deleted meanwhile?
                      final children = await DatabaseService().getChildren();
                      final stillExists =
                      children.any((c) => c['id'] == childId);

                      if (!stillExists) {
                        await _goToRemainingChild(navigator);
                      } else if (selectedId != childId) {
                        // Switched to a different child.
                        await DatabaseService().setActiveChild(selectedId);
                        navigator.pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                DashboardScreen(nickname: selectedId),
                          ),
                        );
                      } else {
                        // Same child: just reload name and avatar.
                        onChanged?.call();
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfileOption({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF4DEB3),
              ),
              child: Icon(icon, color: ColorTheme.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}