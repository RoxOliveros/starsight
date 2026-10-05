import 'package:flutter/material.dart';

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

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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

                    // ── Mission ──
                    _buildInfoCard(
                      color: _AbPalette.orange,
                      icon: Icons.favorite_rounded,
                      title: 'OUR MISSION',
                      body:
                      'We believe every child learns in their own way and '
                          'at their own pace. StarSight turns learning into '
                          'play, while giving grownups gentle insights into '
                          'how their child experiences each activity.',
                    ),
                    const SizedBox(height: 20),

                    // ── What we do ──
                    _buildSectionTitle('WHAT WE OFFER', _AbPalette.teal),
                    const SizedBox(height: 14),
                    _buildFeaturesCard(),
                    const SizedBox(height: 20),

                    // ── Disclaimer ──
                    _buildInfoCard(
                      color: _AbPalette.deepNavyBlue,
                      icon: Icons.info_outline_rounded,
                      title: 'GOOD TO KNOW',
                      body:
                      'Our reports are a helpful guide based on gameplay. '
                          'They are not a medical, psychological, or formal '
                          'educational assessment.',
                    ),
                    const SizedBox(height: 20),

                    // ── Contact ──
                    _buildSectionTitle('GET IN TOUCH', _AbPalette.yellow),
                    const SizedBox(height: 14),
                    _buildContactCard(),
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

  // App logo + name + tagline
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _AbPalette.orange, width: 4),
            ),
            // TODO: replace with your app logo, e.g. Image.asset('assets/...')
            child: const Icon(
              Icons.star_rounded,
              size: 46,
              color: _AbPalette.titleGold,
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
            'Learning through play, with insights\nfor the grownups who care.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
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

  Widget _buildFeaturesCard() {
    const features = [
      (
      Icons.sports_esports_rounded,
      _AbPalette.orange,
      'Fun learning games',
      'Letters, numbers, science, and puzzles in playful worlds.',
      ),
      (
      Icons.insights_rounded,
      _AbPalette.teal,
      'Gentle insights',
      'See how engaged, attentive, and focused your child is.',
      ),
      (
      Icons.hourglass_bottom_rounded,
      _AbPalette.deepNavyBlue,
      'Healthy screen time',
      'Set limits that fit your family\'s routine.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _AbPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AbPalette.teal, width: 1.6),
      ),
      child: Column(
        children: [
          for (int i = 0; i < features.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: features[i].$2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(features[i].$1, size: 22, color: features[i].$2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          features[i].$3,
                          style: const TextStyle(
                            fontFamily: _AbFonts.fredoka,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _AbPalette.deepNavyBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          features[i].$4,
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
            if (i != features.length - 1)
              Divider(
                height: 1,
                color: _AbPalette.teal.withValues(alpha: 0.25),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard() {
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
            icon: Icons.email_outlined,
            label: 'Email us',
            value: 'support@starsight.app', // TODO: your real email
            onTap: () {}, // UI only
          ),
          Divider(
            height: 1,
            color: _AbPalette.yellow.withValues(alpha: 0.4),
          ),
          _ContactRow(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'www.starsight.app', // TODO: your real website
            onTap: () {}, // UI only
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
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
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