import 'package:flutter/material.dart';

abstract class _AccPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color teal = Color(0xFF54BDB8);
  static const Color brown = Color(0xFF6F6764);
  static const Color mutedGrey = Color(0xFFB9B2A9);
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

abstract class _AccFonts {
  static const String fredoka = 'Fredoka';
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  // UI only: replace with FirebaseAuth.instance.currentUser?.email later.
  static const String _email = 'parent@email.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AccPalette.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildRainbowTitle('ACCOUNT')),
                    const SizedBox(height: 28),

                    // ── Email card (orange) ──
                    _buildOutlinedCard(
                      borderColor: _AccPalette.orange,
                      children: [
                        _AccRow(
                          icon: Icons.email_rounded,
                          color: _AccPalette.orange,
                          label: 'Email',
                          value: _email,
                          showChevron: false,
                          trailing: _SwitchAccountButton(
                            onTap: () {}, // UI only
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Security card (teal) ──
                    _buildOutlinedCard(
                      borderColor: _AccPalette.teal,
                      children: [
                        _AccRow(
                          icon: Icons.pin_rounded,
                          color: _AccPalette.teal,
                          label: 'Change PIN',
                          onTap: () {}, // UI only
                        ),
                        Divider(
                          height: 1,
                          color: _AccPalette.teal.withValues(alpha: 0.25),
                        ),
                        _AccRow(
                          icon: Icons.lock_rounded,
                          color: _AccPalette.teal,
                          label: 'Change Password',
                          onTap: () {}, // UI only
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Delete account (red pill) ──
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {}, // UI only
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.6),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'DELETE ACCOUNT',
                          style: TextStyle(
                            fontFamily: _AccFonts.fredoka,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
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
            color: _AccPalette.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Multicolored title (same style as the Grownup's Area)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _AccPalette.titleSky,
      _AccPalette.titleGold,
      _AccPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _AccPalette.brown;
      } else {
        color = palette[(letterIndex ~/ 2) % palette.length];
        letterIndex++;
      }
      spans.add(TextSpan(text: char, style: TextStyle(color: color)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: _AccFonts.fredoka,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildOutlinedCard({
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: Column(children: children),
    );
  }
}

// Small round "switch account" button shown on the email row
class _SwitchAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwitchAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _AccPalette.orange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.swap_horiz_rounded,
          size: 22,
          color: _AccPalette.orange,
        ),
      ),
    );
  }
}

class _AccRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AccRow({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.showChevron = true,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: _AccFonts.fredoka,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _AccPalette.deepNavyBlue,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _AccFonts.fredoka,
                          fontSize: 13,
                          color: _AccPalette.brown,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _AccPalette.deepNavyBlue.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}