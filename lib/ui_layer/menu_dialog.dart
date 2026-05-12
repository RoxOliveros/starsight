import 'package:StarSight/UI_Layer/signup_signin.dart';
import 'package:StarSight/ui_layer/parents_pin.dart';
import 'package:flutter/material.dart';

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

class ProfileDayDialog extends StatelessWidget {
  final String name;

  const ProfileDayDialog({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // pick a responsive square size (adjust 0.75 if you want bigger/smaller)
    final dialogSize =
        (size.width < size.height ? size.width : size.height) * 0.75;

    return Dialog(
      backgroundColor: const Color(0xFFE9C679),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: dialogSize,
        height: dialogSize,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),

          // ✅ makes content scrollable if it overflows
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColorTheme.orange,
                            width: 3,
                          ),
                        ),
                        child: const CircleAvatar(
                          backgroundImage: AssetImage(
                            'assets/drafts/avatar.png',
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTheme.orange,
                          ),
                        ),
                      ),

                      const Icon(
                        Icons.star,
                        color: ColorTheme.yellow,
                        size: 26,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  height: 2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),

                const SizedBox(height: 18),

                _ProfileOption(
                  icon: Icons.nightlight_round,
                  label: "Night Mode",
                  trailing: Container(
                    width: 45,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ColorTheme.orange, width: 2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ColorTheme.orange,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                _ProfileOption(
                  icon: Icons.auto_awesome,
                  label: "Analysis and Reports",
                ),

                const SizedBox(height: 14),

                _ProfileOption(
                  icon: Icons.group,
                  label: "Parent's Area",
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ParentPin(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                _ProfileOption(
                  icon: Icons.logout,
                  label: "Log out",
                  onTap: () {
                    //TODO: @Ron paayos nalang ng backend etc here for log out like literal na ninavigate ko lang to sa sign in sign up
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpSignInScreen(),
                      ),
                    );
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
  final Widget? trailing;
  final VoidCallback? onTap; // ✅ add this

  const _ProfileOption({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // ✅ better than Row alone
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

            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
