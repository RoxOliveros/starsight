import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class _AbPalette {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color teal = Color(0xFF54BDB8);
  static const Color brown = Color(0xFF6F6764);
  static const Color mutedGrey = Color(0xFFB9B2A9);
  static const Color cardYellow = Color(0x80F6CE66);
  static const Color titleSky = Color(0xFF6FD3E3);
  static const Color titleGold = Color(0xFFFACC58);
  static const Color titleOrange = Color(0xFFEC8A20);
}

abstract class _AbFonts {
  static const String fredoka = 'Fredoka';
}

abstract class _AbSupport {
  static const String email = 'intellistar.support@gmail.com';
  static const String subject = 'StarSight Support';
}

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  /// Opens the user's email app with a new message to StarSight support.
  /// If no email app is available, copies the address instead.
  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:${_AbSupport.email}'
          '?subject=${Uri.encodeComponent(_AbSupport.subject)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: _AbSupport.email));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No email app found. The address ${_AbSupport.email} was copied.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AbPalette.cream,
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
                    Center(child: _buildRainbowTitle('ABOUT US')),
                    const SizedBox(height: 24),

                    // ── App intro card ──
                    _buildIntroCard(),
                    const SizedBox(height: 24),

                    // ── Purpose ──
                    _buildInfoCard(
                      color: _AbPalette.orange,
                      icon: Icons.favorite_rounded,
                      title: 'OUR PURPOSE',
                      body:
                      'We believe that early childhood learning should be '
                          'engaging, interactive, and enjoyable. StarSight was '
                          'developed to support parents and teachers in '
                          'observing children\'s interactions with various '
                          'learning activities while encouraging curiosity, '
                          'exploration, and discovery.\n\n'
                          'Through play-based activities and behavioral '
                          'insights, we aim to make observation more '
                          'accessible and provide useful information that can '
                          'help adults better understand each child\'s '
                          'learning experience.',
                    ),
                    const SizedBox(height: 20),

                    // ── What we offer ──
                    _buildSectionTitle('WHAT STARSIGHT OFFERS', _AbPalette.teal),
                    const SizedBox(height: 14),
                    _buildFeaturesCard(),
                    const SizedBox(height: 20),

                    // ── Learning worlds ──
                    _buildSectionTitle('OUR LEARNING WORLDS', _AbPalette.orange),
                    const SizedBox(height: 6),
                    const Text(
                      'StarSight features five interactive learning categories:',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: _AbPalette.brown,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildWorldsCard(),
                    const SizedBox(height: 20),

                    // ── Commitment ──
                    _buildInfoCard(
                      color: _AbPalette.deepNavyBlue,
                      icon: Icons.shield_outlined,
                      title: 'OUR COMMITMENT',
                      body:
                      'StarSight is designed to support, not replace, the '
                          'guidance and supervision of parents and teachers. '
                          'Its behavioral indicators are estimates based on '
                          'observable actions during gameplay and are not '
                          'intended to provide medical, psychological, '
                          'educational, or developmental diagnoses.\n\n'
                          'We value responsible technology use, child privacy, '
                          'and adult supervision throughout the learning '
                          'experience. Our goal is to make technology a '
                          'helpful tool in supporting children\'s early '
                          'learning and observation.',
                    ),
                    const SizedBox(height: 20),

                    // ── Team ──
                    _buildSectionTitle(
                        'MEET THE DEVELOPMENT TEAM', _AbPalette.titleSky),
                    const SizedBox(height: 14),
                    _buildTeamCard(),
                    const SizedBox(height: 20),

                    // ── Contact ──
                    _buildSectionTitle('GET IN TOUCH', _AbPalette.yellow),
                    const SizedBox(height: 6),
                    const Text(
                      'Have questions, feedback, or concerns? '
                          'We\'d love to hear from you!',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: _AbPalette.brown,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildContactCard(context),
                    const SizedBox(height: 32),

                    // ── Footer ──
                    Center(
                      child: Text(
                        'StarSight v0.3.0',
                        style: TextStyle(
                          fontFamily: _AbFonts.fredoka,
                          fontSize: 12,
                          color: _AbPalette.mutedGrey.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'IntelliStar™',
                        style: TextStyle(
                          fontFamily: _AbFonts.fredoka,
                          fontSize: 12,
                          color: _AbPalette.mutedGrey.withValues(alpha: 0.9),
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
            color: _AbPalette.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Multicolored title (same style as the other screens)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _AbPalette.titleSky,
      _AbPalette.titleGold,
      _AbPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _AbPalette.brown;
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
          fontFamily: _AbFonts.fredoka,
          fontSize: 30,
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
        fontFamily: _AbFonts.fredoka,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }

  // App logo + name + tagline + description
  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: _AbPalette.cardYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _AbPalette.orange, width: 4),
            ),
            child: Image.asset(
              'assets/images/logo_transparent_bg.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'STARSIGHT',
            style: TextStyle(
              fontFamily: _AbFonts.fredoka,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _AbPalette.deepNavyBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start your child\'s journey with StarSight!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.4,
              color: _AbPalette.brown,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'StarSight is an AI-assisted learning and behavioral observation '
                'application designed to support early childhood development '
                'through interactive, play-based learning activities.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: _AbPalette.brown,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Developed by IntelliStar, StarSight provides parents and '
                'teachers with an additional way to observe how children '
                'interact with different learning activities. By combining '
                'engaging educational games with AI-assisted behavioral '
                'tracking, the application provides insights into children\'s '
                'observable attention, focus, and engagement during gameplay.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: _AbPalette.brown,
            ),
          ),
        ],
      ),
    );
  }

  // Simple outlined card with icon + title + paragraph
  Widget _buildInfoCard({
    required Color color,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: _AbFonts.fredoka,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: _AbPalette.brown,
            ),
          ),
        ],
      ),
    );
  }

  // Shared card: list of (icon, color, title, description) rows with dividers
  Widget _buildItemsCard({
    required Color borderColor,
    required List<(IconData, Color, String, String)> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _AbPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: items[i].$2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(items[i].$1, size: 22, color: items[i].$2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$3,
                          style: const TextStyle(
                            fontFamily: _AbFonts.fredoka,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _AbPalette.deepNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$4,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: _AbPalette.brown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Divider(
                height: 1,
                color: borderColor.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return _buildItemsCard(
      borderColor: _AbPalette.teal,
      items: const [
        (
        Icons.sports_esports_rounded,
        _AbPalette.orange,
        'Play-Based Learning',
        'Interactive activities covering letters, numbers, values, basic '
            'concepts, colors, patterns, and puzzles.',
        ),
        (
        Icons.visibility_rounded,
        _AbPalette.teal,
        'Behavioral Observation',
        'AI-assisted tracking of observable behaviors during gameplay, '
            'including eye and gaze movement, head movement, facial cues, '
            'and screen interactions.',
        ),
        (
        Icons.insights_rounded,
        _AbPalette.titleSky,
        'Behavioral Reports',
        'Organized insights into estimated attention, focus, and '
            'engagement to help parents and teachers observe children\'s '
            'interactions with learning activities.',
        ),
        (
        Icons.family_restroom_rounded,
        _AbPalette.deepNavyBlue,
        'Parental Controls',
        'Settings for managing child profiles, audio preferences, and '
            'screen-time limits.',
        ),
      ],
    );
  }

  Widget _buildWorldsCard() {
    return _buildItemsCard(
      borderColor: _AbPalette.orange,
      items: const [
        (
        Icons.park_rounded,
        _AbPalette.teal,
        'Alphabet Forest',
        'Explore letters, letter recognition, and pronunciation.',
        ),
        (
        Icons.home_rounded,
        _AbPalette.orange,
        'Lumi Town',
        'Discover values, emotions, family, and everyday manners.',
        ),
        (
        Icons.ac_unit_rounded,
        _AbPalette.titleSky,
        'Arctic Numberland',
        'Practice number recognition, tracing, and counting.',
        ),
        (
        Icons.water_rounded,
        _AbPalette.deepNavyBlue,
        'Discovery Lagoon',
        'Explore basic concepts and learn about the world around us.',
        ),
        (
        Icons.extension_rounded,
        _AbPalette.titleGold,
        'Puzzle Glade',
        'Develop problem-solving skills through matching, sorting, '
            'patterns, and puzzles.',
        ),
      ],
    );
  }

  Widget _buildTeamCard() {
    const members = [
      'Roxanne Oliveros',
      'Christine Domat-ol',
      'Ron Cyrus Medina',
    ];
    const colors = [
      _AbPalette.orange,
      _AbPalette.teal,
      _AbPalette.deepNavyBlue,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: _AbPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AbPalette.titleSky, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'StarSight is developed by IntelliStar, a team of three Bachelor '
                'of Science in Information Technology students:',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: _AbPalette.brown,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < members.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: colors[i],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    members[i],
                    style: const TextStyle(
                      fontFamily: _AbFonts.fredoka,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _AbPalette.deepNavyBlue,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            'Together, the team developed StarSight as a project that brings '
                'together technology, interactive learning, and AI-assisted '
                'behavioral observation to support early childhood '
                'development.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: _AbPalette.brown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _AbPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AbPalette.yellow, width: 1.6),
      ),
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.groups_rounded,
            label: 'Development Team',
            value: 'IntelliStar',
          ),
          Divider(
            height: 1,
            color: _AbPalette.yellow.withValues(alpha: 0.4),
          ),
          _ContactRow(
            icon: Icons.star_rounded,
            label: 'Application',
            value: 'StarSight',
          ),
          Divider(
            height: 1,
            color: _AbPalette.yellow.withValues(alpha: 0.4),
          ),
          _ContactRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _AbSupport.email,
            onTap: () => _contactSupport(context),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _AbPalette.yellow),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: _AbFonts.fredoka,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _AbPalette.deepNavyBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _AbPalette.brown,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _AbPalette.deepNavyBlue.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}