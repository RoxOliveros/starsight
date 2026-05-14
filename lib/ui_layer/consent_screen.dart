import 'package:StarSight/ui_layer/dashboard.dart';
import 'package:flutter/material.dart';
import '../business_layer/database_service.dart';
import '../business_layer/lottie_cache.dart';

abstract class ColorTheme {
  static const Color cream = Color(0xFFFAF7EB);
  static const Color deepNavyBlue = Color(0xFF5F7199);
  static const Color blue = Color(0xFF4C89C3);
  static const Color lightblue = Color(0xFF6FD3E3);
  static const Color orange = Color(0xFFEC8A20);
  static const Color yellow = Color(0xFFF9D552);
  static const Color yelloworange = Color(0xFFFACC58);
  static const Color brown = Color(0xFF6F6764);
}

abstract class AppTextStyles {
  static const String fredoka = 'Fredoka';
  static const String nunito = 'Nunito';
}

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _section2Key = GlobalKey();
  final GlobalKey _section3Key = GlobalKey();
  final GlobalKey _section4Key = GlobalKey();

  // 1 = only section 1 visible, 2 = section 2 revealed, etc.
  int _revealedSections = 1;
  bool _isChecked = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTapScreen() {
    if (_revealedSections >= 3) return; // all sections already revealed
    setState(() => _revealedSections++);

    // scroll to newly revealed section after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalKey targetKey;
      if (_revealedSections == 2) {
        targetKey = _section2Key;
      } else if (_revealedSections == 3) {
        targetKey = _section3Key;
      } else {
        return;
      }

      final ctx = targetKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  void showAllowedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AllowedDialog(),
    );
  }

  void _onAllowAndContinue() {
    if (!_isChecked) return;
    showAllowedDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      body: SafeArea(
        child: GestureDetector(
          // tap anywhere to reveal next section (but not on interactive widgets)
          onTap: _revealedSections < 3 ? _onTapScreen : null,
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Back arrow ──────────────────────────────────────────
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: ColorTheme.deepNavyBlue,
                    size: 24,
                  ),
                ),

                // ════════════════════════════════════════════════════════
                // SECTION 1 — Quick note for parents
                // ════════════════════════════════════════════════════════
                _Section1(),

                // ════════════════════════════════════════════════════════
                // SECTION 2 — This helps us understand
                // ════════════════════════════════════════════════════════
                if (_revealedSections >= 2) ...[
                  const SizedBox(height: 40),
                  _Section2(key: _section2Key),
                ],

                // ════════════════════════════════════════════════════════
                // SECTION 3 — Your child's safety
                // ════════════════════════════════════════════════════════
                if (_revealedSections >= 3) ...[
                  const SizedBox(height: 40),
                  _Section3(key: _section3Key),
                  const SizedBox(height: 40),
                  _Section4(
                    key: _section4Key,
                    isChecked: _isChecked,
                    onCheckChanged: (val) =>
                        setState(() => _isChecked = val ?? false),
                    onAllow: _onAllowAndContinue,
                  ),
                ],

                const SizedBox(height: 40),

                // Tap hint — only show when more sections remain
                if (_revealedSections < 3)
                  Center(
                    child: Text(
                      'Tap to continue reading...',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 13,
                        color: ColorTheme.deepNavyBlue.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 1 — "A quick note for parents"
// ══════════════════════════════════════════════════════════════════════════════
class _Section1 extends StatefulWidget {
  const _Section1();

  @override
  State<_Section1> createState() => _Section1State();
}

class _Section1State extends State<_Section1> {
  int _visibleSensors = 0; // 0 = none visible yet

  @override
  void initState() {
    super.initState();
    _revealSensorsSequentially();
  }

  void _revealSensorsSequentially() async {
    for (int i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _visibleSensors = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // Title
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: 'A QUICK NOTE FOR',
                style: TextStyle(color: ColorTheme.brown),
              ),
            ],
          ),
        ),

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: 'PA',
                style: TextStyle(color: ColorTheme.lightblue),
              ),
              TextSpan(
                text: 'RE',
                style: TextStyle(color: ColorTheme.orange),
              ),
              TextSpan(
                text: 'NT',
                style: TextStyle(color: ColorTheme.yellow),
              ),
              TextSpan(
                text: 'S',
                style: TextStyle(color: ColorTheme.lightblue),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Info box with stars
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(color: ColorTheme.deepNavyBlue, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: AppTextStyles.nunito,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ColorTheme.brown,
                  ),
                  children: [
                    TextSpan(
                      text: 'StarSight ',
                      style: TextStyle(color: ColorTheme.yellow),
                    ),
                    TextSpan(text: 'Gently '),
                    TextSpan(
                      text: 'Observes ',
                      style: TextStyle(color: ColorTheme.lightblue),
                    ),
                    TextSpan(text: 'How Your\nChild Learns While They Play.'),
                  ],
                ),
              ),
            ),
            // top-left star
            Positioned(
              top: -30,
              left: -25,
              child: Transform.rotate(angle: 0.5, child: _StarIcon(size: 60)),
            ),
            // bottom-right star
            Positioned(
              bottom: -20,
              right: -20,
              child: Transform.rotate(angle: -0.3, child: _StarIcon(size: 50)),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // "WE MAY USE"
        Text(
          'WE MAY USE',
          style: TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ColorTheme.orange,
          ),
        ),

        const SizedBox(height: 20),

        // 4 icons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AnimatedSensorItem(
              visible: _visibleSensors >= 1,
              asset: 'assets/images/eye.png',
              label: 'Eye Focus',
            ),
            _AnimatedSensorItem(
              visible: _visibleSensors >= 2,
              asset: 'assets/images/hand.png',
              label: 'Hand\nMovement',
            ),
            _AnimatedSensorItem(
              visible: _visibleSensors >= 3,
              asset: 'assets/images/audio.png',
              label: 'Audio &\nSpeech',
            ),
            _AnimatedSensorItem(
              visible: _visibleSensors >= 4,
              asset: 'assets/images/face.png',
              label: 'Facial\nExpressions',
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 2 — "This helps us understand"
// ══════════════════════════════════════════════════════════════════════════════
class _Section2 extends StatefulWidget {
  const _Section2({super.key});

  @override
  State<_Section2> createState() => _Section2State();
}

class _Section2State extends State<_Section2> {
  int _visibleChips = 0;

  @override
  void initState() {
    super.initState();
    _revealChipsSequentially();
  }

  void _revealChipsSequentially() async {
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(milliseconds: 1300));
      if (mounted) setState(() => _visibleChips = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '\nTHIS HELPS US UNDERSTAND',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ColorTheme.deepNavyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "YOUR CHILD'S LEARNING BEHAVIOR, SUCH AS:",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorTheme.brown,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  _AnimatedChip(
                    visible: _visibleChips >= 1,
                    text: 'How Well They Stay Focused On Activities',
                    color: ColorTheme.lightblue,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedChip(
                    visible: _visibleChips >= 2,
                    text: 'How They Approach And Complete Tasks',
                    color: ColorTheme.orange,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedChip(
                    visible: _visibleChips >= 3,
                    text: 'How They Feel And React While Playing',
                    color: ColorTheme.yellow,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/bunny_holding_star.png',
              height: 130,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 3 — "Your child's safety comes first"
// ══════════════════════════════════════════════════════════════════════════════
class _Section3 extends StatefulWidget {
  const _Section3({super.key});

  @override
  State<_Section3> createState() => _Section3State();
}

class _Section3State extends State<_Section3> {
  int _visibleBullets = 0;

  @override
  void initState() {
    super.initState();
    _revealBulletsSequentially();
  }

  void _revealBulletsSequentially() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    for (int i = 1; i <= _bullets.length; i++) {
      if (mounted) {
        setState(() => _visibleBullets = i);
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  static const _bullets = [
    "Your Child's Data Is Safely Stored And Protected. We Do Not Share Personal Information With Third Parties.",
    "StarSight Provides Learning Insights Only. It Does Not Diagnose Or Replace Professional Evaluation.",
    "All Insights And Reports Are Accessible Only To Parents Or Authorized Guardians.",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/cat_holding_fishbone.png', height: 130),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"YOUR CHILD\'S SAFETY\nCOMES FIRST"',
                style: const TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ColorTheme.yelloworange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: ColorTheme.deepNavyBlue, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: List.generate(_bullets.length, (index) {
              final isLast = index == _bullets.length - 1;
              final visible = _visibleBullets > index;
              return Column(
                children: [
                  AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 1500),
                    child: AnimatedSlide(
                      offset: visible ? Offset.zero : const Offset(-0.2, 0),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOut,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _StarIcon(size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _bullets[index],
                              style: const TextStyle(
                                fontFamily: AppTextStyles.nunito,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorTheme.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) const SizedBox(height: 16),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION 4 — Checkbox + CTA buttons
// ══════════════════════════════════════════════════════════════════════════════
class _Section4 extends StatelessWidget {
  final bool isChecked;
  final ValueChanged<bool?> onCheckChanged;
  final VoidCallback onAllow;

  const _Section4({
    super.key,
    required this.isChecked,
    required this.onCheckChanged,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Checkbox row
        GestureDetector(
          onTap: () => onCheckChanged(!isChecked),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isChecked ? ColorTheme.orange : Colors.transparent,
                  border: Border.all(color: ColorTheme.orange, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I Understand And Allow StarSight To Use AI-Assisted Observation During Activities',
                  style: TextStyle(
                    fontFamily: AppTextStyles.nunito,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ColorTheme.brown,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Allow & Continue button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isChecked ? onAllow : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorTheme.yellow,
              disabledBackgroundColor: ColorTheme.yellow.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text(
              'Allow & Continue',
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ══════════════════════════════════════════════════════════════════════════════
class _StarIcon extends StatelessWidget {
  final double size;

  const _StarIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/night_star.png',
      width: size,
      height: size,
    );
  }
}

class _SensorItem extends StatelessWidget {
  final String asset;
  final String label;

  const _SensorItem({required this.asset, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(asset, width: 44, height: 44),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.nunito,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: ColorTheme.brown,
          ),
        ),
      ],
    );
  }
}

class _AnimatedSensorItem extends StatelessWidget {
  final bool visible;
  final String asset;
  final String label;

  const _AnimatedSensorItem({
    required this.visible,
    required this.asset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 1000),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOut,
        child: _SensorItem(asset: asset, label: label),
      ),
    );
  }
}

class _BehaviorChip extends StatelessWidget {
  final String text;
  final Color color;

  const _BehaviorChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.nunito,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: ColorTheme.brown,
        ),
      ),
    );
  }
}

class _AnimatedChip extends StatelessWidget {
  final bool visible;
  final String text;
  final Color color;

  const _AnimatedChip({
    required this.visible,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSlide(
        offset: visible
            ? Offset.zero
            : const Offset(-0.2, 0), // slides in from left
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: _BehaviorChip(text: text, color: color),
      ),
    );
  }
}

class _AllowedDialog extends StatelessWidget {
  const _AllowedDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorTheme.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Close button ──────────────────────────────────────
            Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close,
                  color: ColorTheme.deepNavyBlue,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Jar illustration ──────────────────────────────────
            Image.asset(
              'assets/images/jar_on_grass.png',
              height: 150,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 20),

            // ── Message ───────────────────────────────────────────
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ColorTheme.brown,
                ),
                children: [
                  TextSpan(text: "Yay! You're all set for a smarter\n"),
                  TextSpan(
                    text: 'learning journey',
                    style: TextStyle(color: ColorTheme.orange),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Button ────────────────────────────────────────────
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () async {
                  String fetchedNickname = await DatabaseService()
                      .getNickname();

                  if (!context.mounted) return;

                  Navigator.of(context).pop();

                  await LottieCache.instance.preload([
                    'assets/animations/forest.json',
                    'assets/animations/town.json',
                    'assets/animations/arctic.json',
                    'assets/animations/lagoon.json',
                    'assets/animations/puzzle.json',
                    'assets/animations/white_clouds_mirrored.json',
                    'assets/animations/white_cloud.json',
                    'assets/animations/movie_clapperboard.json',
                  ]);

                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DashboardScreen(nickname: fetchedNickname),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorTheme.yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Go to Dashboard',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
