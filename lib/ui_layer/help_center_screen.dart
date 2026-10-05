import 'package:flutter/material.dart';

abstract class _HcPalette {
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

abstract class _HcFonts {
  static const String fredoka = 'Fredoka';
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}

class _FaqGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FaqItem> items;

  const _FaqGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<_FaqGroup> _groups = [
    _FaqGroup(
      title: 'GETTING STARTED',
      icon: Icons.rocket_launch_rounded,
      color: _HcPalette.orange,
      items: [
        _FaqItem(
          'How do I add another child?',
          'Open the Grownup\'s Area and tap the + Add Child circle in the '
              'Your Children card. Fill in your child\'s details and save.',
        ),
        _FaqItem(
          'How do I switch between children?',
          'Tap a child\'s avatar in the Your Children card, then confirm. '
              'The reports and settings shown will be for that child.',
        ),
      ],
    ),
    _FaqGroup(
      title: 'REPORTS',
      icon: Icons.insights_rounded,
      color: _HcPalette.teal,
      items: [
        _FaqItem(
          'How do I read my child\'s report?',
          'Open Child\'s Area and pick a subject. Each report shows '
              'Engagement, Attention, and Focus in simple, friendly words. '
              'Tap Learn More on any of them for details.',
        ),
        _FaqItem(
          'Are the reports a medical assessment?',
          'No. Reports are a helpful guide based on how your child plays. '
              'They are not a medical, psychological, or formal educational '
              'assessment. Please talk to a teacher or qualified professional '
              'if you have concerns.',
        ),
        _FaqItem(
          'How can I save a report?',
          'Go to Backup > Download Analysis, choose the subjects you want, '
              'and tap Download PDF.',
        ),
      ],
    ),
    _FaqGroup(
      title: 'SAFETY & SETTINGS',
      icon: Icons.shield_rounded,
      color: _HcPalette.deepNavyBlue,
      items: [
        _FaqItem(
          'How do I set a screen time limit?',
          'In the Your Children card, use the Screen Time dropdown to pick '
              '15, 30, 45, or 60 minutes. Choose Off to remove the limit.',
        ),
        _FaqItem(
          'I forgot my PIN. What can I do?',
          'Tap Forgot PIN? on the PIN screen and follow the steps to '
              'reset it.',
        ),
        _FaqItem(
          'How do I turn the music or sounds off?',
          'Go to Settings > Music and Sounds. You can switch music, sound '
              'effects, and voice narration on or off, and adjust their '
              'volume.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HcPalette.cream,
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
                    Center(child: _buildRainbowTitle('HELP CENTER')),
                    const SizedBox(height: 8),
                    const Text(
                      'Quick answers to common questions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _HcPalette.brown,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Search (UI only) ──
                    _buildSearchBar(),
                    const SizedBox(height: 26),

                    // ── FAQ groups ──
                    for (final g in _groups) ...[
                      _buildGroupTitle(g),
                      const SizedBox(height: 14),
                      _buildFaqCard(g),
                      const SizedBox(height: 26),
                    ],

                    // ── Contact support ──
                    _buildContactCard(),
                    const SizedBox(height: 28),

                    Center(
                      child: Text(
                        'StarSight v0.3.0',
                        style: TextStyle(
                          fontFamily: _HcFonts.fredoka,
                          fontSize: 12,
                          color: _HcPalette.mutedGrey.withValues(alpha: 0.9),
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
            color: _HcPalette.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Multicolored title (same style as the other screens)
  Widget _buildRainbowTitle(String text) {
    const palette = [
      _HcPalette.titleSky,
      _HcPalette.titleGold,
      _HcPalette.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = _HcPalette.brown;
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
          fontFamily: _HcFonts.fredoka,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _HcPalette.deepNavyBlue, width: 1.6),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 22, color: _HcPalette.deepNavyBlue),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              // UI only: no search logic yet
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _HcPalette.brown,
              ),
              decoration: InputDecoration(
                hintText: 'Search for help',
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _HcPalette.mutedGrey,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(_FaqGroup g) {
    return Row(
      children: [
        Icon(g.icon, size: 22, color: g.color),
        const SizedBox(width: 10),
        Text(
          g.title,
          style: TextStyle(
            fontFamily: _HcFonts.fredoka,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: g.color,
          ),
        ),
      ],
    );
  }

  Widget _buildFaqCard(_FaqGroup g) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _HcPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: g.color, width: 1.6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (int i = 0; i < g.items.length; i++) ...[
              _FaqTile(item: g.items[i], color: g.color),
              if (i != g.items.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: g.color.withValues(alpha: 0.25),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: _HcPalette.cardYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _HcPalette.orange, width: 3),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 28,
              color: _HcPalette.orange,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'STILL NEED HELP?',
            style: TextStyle(
              fontFamily: _HcFonts.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _HcPalette.deepNavyBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Our team is happy to help. Send us a message and we\'ll get '
                'back to you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: _HcPalette.brown,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {}, // UI only
              style: ElevatedButton.styleFrom(
                backgroundColor: _HcPalette.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.email_rounded, size: 20),
              label: const Text(
                'CONTACT SUPPORT',
                style: TextStyle(
                  fontFamily: _HcFonts.fredoka,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One expandable question/answer row.
class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  final Color color;

  const _FaqTile({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Removes the default divider lines ExpansionTile draws.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: color,
        collapsedIconColor: _HcPalette.deepNavyBlue.withValues(alpha: 0.5),
        title: Text(
          item.question,
          style: const TextStyle(
            fontFamily: _HcFonts.fredoka,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _HcPalette.deepNavyBlue,
          ),
        ),
        children: [
          Text(
            item.answer,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: _HcPalette.brown,
            ),
          ),
        ],
      ),
    );
  }
}