import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

abstract class _HcSupport {
  static const String email = 'intellistar.support@gmail.com';
  static const String subject = 'StarSight Support';
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
      title: 'ABOUT STARSIGHT',
      icon: Icons.info_outline_rounded,
      color: _HcPalette.orange,
      items: [
        _FaqItem(
          "What is StarSight?",
          "StarSight is an AI-assisted mobile application designed to help parents and teachers observe a child's learning behavior while participating in play-based learning activities. It uses behavioral tracking and AI-assisted analysis to provide insights about the child's observed attention, focus, and engagement.",
        ),
        _FaqItem(
          "Who can use StarSight?",
          "StarSight is intended for parents, guardians, and teachers who supervise children while they use the application. Children can participate in the learning activities, but they must always be under the direct supervision of an adult.",
        ),
        _FaqItem(
          "Is StarSight a diagnostic tool?",
          "No. StarSight is designed for non-diagnostic purposes only. It provides observational insights based on the child's visible behavior and interactions during gameplay. It does not diagnose developmental conditions, psychological disorders, or medical concerns.",
        ),
        _FaqItem(
          "Does StarSight evaluate a child's intelligence or academic performance?",
          "No. StarSight is not designed to measure IQ, assign academic grades, or determine whether a child has achieved specific learning milestones. Its main purpose is to observe how a child interacts with the learning activities.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'ACCOUNT & SIGN UP',
      icon: Icons.manage_accounts_rounded,
      color: _HcPalette.teal,
      items: [
        _FaqItem(
          "How do I create a StarSight account?",
          "1. Open the StarSight app.\n"
              "2. Tap Sign Up.\n"
              "3. Enter your child's details and create your four-digit Parent PIN.\n"
              "4. Register with your email and password, or with your Google account.\n"
              "5. Review and confirm the required consent before you continue.",
        ),
        _FaqItem(
          "How do I sign in to my account?",
          "Open StarSight and tap Sign In. Enter your registered email and password, or choose the Google sign-in option for the account you used to register.",
        ),
        _FaqItem(
          "What should I do if I forget my password?",
          "On the sign-in screen, type your email address and tap Forgot Password?. We will send a link to your email so you can reset your password. Check your spam folder if you don't see it.",
        ),
        _FaqItem(
          "What is the Parent PIN?",
          "The Parent PIN is a four-digit security code you set up during registration. It helps protect the grownup features and settings. Keep your PIN private and don't share it with unauthorized people.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'CHILD PROFILES',
      icon: Icons.child_care_rounded,
      color: _HcPalette.deepNavyBlue,
      items: [
        _FaqItem(
          "How do I add a child's profile?",
          "1. Sign in to your StarSight account.\n"
              "2. Open the Grownup's Area.\n"
              "3. Tap the + Add Child circle in the Your Children card.\n"
              "4. Enter your child's nickname, birthdate, avatar, and gender.\n"
              "5. Save the profile.",
        ),
        _FaqItem(
          "Can I edit a child's profile after creating it?",
          "Yes. Open the Grownup's Area, select your child's profile, and choose the edit option. Update the available information and save your changes.",
        ),
        _FaqItem(
          "Can I delete a child's profile?",
          "Yes. You can permanently delete a child's profile through the account settings. Read the confirmation message carefully before you continue, because deleting a profile is permanent.",
        ),
        _FaqItem(
          "Can I manage more than one child's profile?",
          "Yes. StarSight lets you add and manage child profiles from the Grownup's Area. The number of profiles you can create may depend on the app's configured limits.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'LEARNING ACTIVITIES',
      icon: Icons.sports_esports_rounded,
      color: _HcPalette.yellow,
      items: [
        _FaqItem(
          "What learning categories are available in StarSight?",
          "StarSight has five learning categories:\n\n"
              "• Alphabet Forest: letters, pronunciation, and uppercase-to-lowercase matching.\n"
              "• Lumi Town: stories and activities about sharing, emotions, family, house chores, and basic manners.\n"
              "• Arctic Numberland: number tracing, number recognition, counting, and object identification.\n"
              "• Discovery Lagoon: basic science topics such as body parts, the five senses, weather, animals, food groups, and seasons.\n"
              "• Puzzle Glade: color sorting, pattern recognition, memory matching, shadow matching, puzzles, and other logic-based activities.",
        ),
        _FaqItem(
          "Why are some game levels locked?",
          "Some levels stay locked until your child meets the required condition in the learning activities. Finish the current level or activity to unlock the next one.",
        ),
        _FaqItem(
          "What happens when a child exits a game before finishing it?",
          "StarSight records the gameplay data that is available. However, an unfinished activity may not give enough information for a complete behavioral analysis.",
        ),
        _FaqItem(
          "Does StarSight provide audio instructions?",
          "Yes. StarSight includes interactive audio in its learning activities. You can change the audio settings in the Grownup's Area under Settings > Music and Sounds.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'CAMERA & TRACKING',
      icon: Icons.videocam_rounded,
      color: _HcPalette.orange,
      items: [
        _FaqItem(
          "Why does StarSight need camera access?",
          "During learning activities, StarSight uses the device camera to observe visible behavioral cues such as eye or gaze movement, head movement, and facial expressions. These observations help generate attention, focus, and engagement indicators.",
        ),
        _FaqItem(
          "Does StarSight record or save videos or photos of my child?",
          "No. StarSight does not record or save videos or photos of your child. The camera is used for real-time tracking only. Camera frames are processed as your child plays, and only the resulting behavioral metrics are kept for analysis and reporting. To learn more, read the Privacy Policy.",
        ),
        _FaqItem(
          "How can I help StarSight track my child properly?",
          "• Place the device in a stable position.\n"
              "• Make sure your child's face is visible in the camera frame.\n"
              "• Use a well-lit room.\n"
              "• Keep the area in front of the camera clear.\n"
              "• Don't cover the camera.\n"
              "• Keep your child within the camera frame during the activity.",
        ),
        _FaqItem(
          "Why can't StarSight detect my child's face or eyes?",
          "Tracking may not work well if the room is too dark, the camera is blocked, your child moves out of the camera frame, or the device doesn't have enough processing power. Check the camera position and lighting, then try again with your child properly in front of the device.",
        ),
        _FaqItem(
          "Does looking away always mean my child is distracted?",
          "No. Eye or gaze movement is only one observable indicator. Looking away doesn't automatically mean a child is distracted or uninterested. StarSight uses several behavioral indicators, and the results should be read together with your own observations as a parent or teacher.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'REPORTS & PROGRESS',
      icon: Icons.insights_rounded,
      color: _HcPalette.teal,
      items: [
        _FaqItem(
          "What does a StarSight behavioral report contain?",
          "A report shows insights from your child's activity, including indicators for attention, focus, and engagement. They are based on tracked behavior such as eye or gaze movement, head movement, facial cues, screen taps, and time spent playing each level.",
        ),
        _FaqItem(
          "How can I view my child's behavioral report?",
          "1. Sign in to your StarSight account.\n"
              "2. Open the Grownup's Area.\n"
              "3. Select your child's profile.\n"
              "4. Tap Child's Area and choose a subject to see the available analysis.\n\n"
              "A report can only be created when there is enough behavioral data.",
        ),
        _FaqItem(
          "Can I download my child's behavioral report?",
          "Yes. Go to Backup > Download Analysis, choose the subjects you want, and tap Download PDF. The PDF is a separate copy outside the app, so keep it somewhere safe and don't share it with people who shouldn't see it.",
        ),
        _FaqItem(
          "Why is my child's behavioral report unavailable?",
          "A report may be unavailable if there isn't enough behavioral data, the activity wasn't finished, tracking conditions were poor, or a network or system error happened. Let your child finish an activity in good tracking conditions, then check again.",
        ),
        _FaqItem(
          "Should I use the report to assess my child's development?",
          "No. Use the report only as an observational reference. It is not a medical, psychological, or developmental assessment. Consider your child's overall behavior, and talk to a qualified professional if you have concerns about development.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'GAME TIME & SETTINGS',
      icon: Icons.hourglass_bottom_rounded,
      color: _HcPalette.deepNavyBlue,
      items: [
        _FaqItem(
          "Can I set a screen-time limit for my child?",
          "Yes. In the Your Children card, use the Game Time dropdown to pick 15, 30, 45, or 60 minutes, or choose Off to remove the limit. When time is up, the game stops. A grownup can enter the Parent PIN to give your child a little more time.",
        ),
        _FaqItem(
          "Can I change the audio settings?",
          "Yes. Go to Settings > Music and Sounds in the Grownup's Area. You can switch music, sound effects, and voice narration on or off, and adjust their volume.",
        ),
        _FaqItem(
          "How do I change my password or Parent PIN?",
          "Open the Grownup's Area, go to Settings > Account, and choose the option to change your password or Parent PIN. Follow the verification and update steps.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'PRIVACY & SECURITY',
      icon: Icons.shield_rounded,
      color: _HcPalette.yellow,
      items: [
        _FaqItem(
          "Who can view my child's profile and behavioral report?",
          "Only the parent or teacher linked to the child's profile should be able to view or edit that child's profile and report.",
        ),
        _FaqItem(
          "How does StarSight protect my child's information?",
          "StarSight restricts access to child profiles and reports. Camera tracking is designed for real-time processing, and videos and photos are not recorded or saved. For more about how personal information is handled, read the Privacy Policy.",
        ),
        _FaqItem(
          "How do I delete my StarSight account?",
          "Open the Grownup's Area, go to Settings > Account, and tap Delete Account. After you confirm, we permanently delete your account information, your child's information, and all associated analysis from our active systems. Deleted data may stay in secure backups for up to 180 days before it is removed. Accounts with no login for 12 months are also deleted, and we send an email warning 30 days before.",
        ),
        _FaqItem(
          "Where can I read StarSight's privacy and usage policies?",
          "At the bottom of the Grownup's Area, tap Privacy Policy or Terms of Use. You can also open them from the sign-up and sign-in screens.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'TROUBLESHOOTING',
      icon: Icons.build_rounded,
      color: _HcPalette.orange,
      items: [
        _FaqItem(
          "What should I do if a game doesn't load?",
          "Check your internet connection and make sure the app is working properly. If the problem continues, close and reopen the app, then try the activity again.",
        ),
        _FaqItem(
          "Why is my dashboard or report taking so long to load?",
          "Loading can be slow because of a weak internet connection, missing data, or a temporary system problem. Check your connection and try again.",
        ),
        _FaqItem(
          "What should I do if my information doesn't save?",
          "Make sure all required fields are filled in correctly and that your device is connected to the internet, then try saving again. If it keeps happening, the app may be having a database or network problem.",
        ),
        _FaqItem(
          "What should I do if I get an error while using StarSight?",
          "Close and reopen the app. Check your internet connection, and make sure the camera isn't blocked when you use an activity that needs tracking. If the problem continues, contact our support team with a description or screenshot of the error. Don't include sensitive personal information in screenshots.",
        ),
      ],
    ),
    _FaqGroup(
      title: 'MORE HELP',
      icon: Icons.support_agent_rounded,
      color: _HcPalette.teal,
      items: [
        _FaqItem(
          "Where can I get more help?",
          "If your question isn't answered here, tap Contact Support below to email us at ${_HcSupport.email}.\n\n"
              "Please include:\n"
              "• A short description of the problem.\n"
              "• The feature or screen where it happened.\n"
              "• The steps you took before the problem.\n"
              "• A screenshot of the error, if it is safe to share.\n\n"
              "Please don't include your password, Parent PIN, or other confidential information.",
        ),
      ],
    ),
  ];

  /// Opens the user's email app with a new message to StarSight support.
  /// If no email app is available, copies the address instead.
  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:${_HcSupport.email}'
          '?subject=${Uri.encodeComponent(_HcSupport.subject)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: _HcSupport.email));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No email app found. The address ${_HcSupport.email} was copied.',
            ),
          ),
        );
      }
    }
  }

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
                    _buildContactCard(context),
                    const SizedBox(height: 18),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'StarSight is an AI-assisted observational and '
                            'play-based learning application. It is intended to '
                            'support parents and teachers, not replace adult '
                            'supervision, professional judgment, or formal '
                            'developmental assessment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: _HcPalette.mutedGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

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
        Expanded(
          child: Text(
            g.title,
            style: TextStyle(
              fontFamily: _HcFonts.fredoka,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: g.color,
            ),
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

  Widget _buildContactCard(BuildContext context) {
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
              onPressed: () => _contactSupport(context),
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
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _contactSupport(context),
            child: const Text(
              _HcSupport.email,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _HcPalette.deepNavyBlue,
                decoration: TextDecoration.underline,
                decorationColor: _HcPalette.deepNavyBlue,
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