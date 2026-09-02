import 'package:flutter/material.dart';
import 'analysis_report_screen.dart';
import 'parents_area_screen.dart';

class SubjectAnalysisScreen extends StatelessWidget {
  final SubjectAnalysis subject;

  const SubjectAnalysisScreen({super.key, required this.subject});

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _getCharacterAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('alphabet forest')) {
      return 'assets/animations/characters/tofi_reading.webp';
    } else if (lower.contains('lumitown')) {
      return 'assets/animations/characters/drwoo_teaching.webp';
    } else if (lower.contains('arctic numberland')) {
      return 'assets/animations/characters/doma_writing_on_board.webp';
    } else if (lower.contains('discovery lagoon')) {
      return 'assets/animations/characters/kiki_fishing.webp';
    } else if (lower.contains('puzzle glade')) {
      return 'assets/animations/characters/roxie_puzzle.webp';
    }
    return subject.characterAsset;
  }

  // ── Detailed, subject-specific descriptions ────────────────────────────
  // Mirrors the pattern of _getCharacterAsset so every subject gets a rich,
  // multi-part blurb instead of a single-word/short tagline.
  String _getSubjectDescription(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('alphabet forest')) {
      return 'A fun learning area where children explore letters, sounds, '
          'and simple words through interactive activities.';
    } else if (lower.contains('lumitown')) {
      return 'A bright learning town where children build general knowledge '
          'through guided lessons, curious questions, and hands-on '
          'discovery activities.';
    } else if (lower.contains('arctic numberland')) {
      return 'A chilly numbers world where children practice counting, '
          'shapes, and simple math concepts through playful, interactive '
          'challenges.';
    } else if (lower.contains('discovery lagoon')) {
      return 'An underwater adventure where children explore science and '
          'nature through hands-on experiments and guided exploration '
          'activities.';
    } else if (lower.contains('puzzle glade')) {
      return 'A playful puzzle world where children build logic, memory, '
          'and problem-solving skills through fun, interactive brain '
          'games.';
    }
    // Fallback to whatever the model provides if the subject isn't
    // recognized above.
    return subject.tagline.isNotEmpty
        ? subject.tagline
        : 'A fun learning area where children build new skills through '
        'interactive, age-appropriate activities.';
  }

  // ── Short, encouraging tips shown in the "Learn More" dialog ──────────
  List<String> _getBandTips(InsightBand band) {
    switch (band) {
      case InsightBand.confident:
        return [
          'Keep sessions consistent to maintain this strong momentum.',
          'Introduce slightly harder activities to keep it challenging.',
          'Celebrate wins together — confidence grows with recognition.',
        ];
      case InsightBand.developing:
        return [
          'Short, regular practice sessions help reinforce progress.',
          'Revisit trickier activities after a few days to build mastery.',
          'Offer gentle encouragement — steady growth is happening.',
        ];
      case InsightBand.emerging:
        return [
          'Try shorter, more frequent sessions to build familiarity.',
          'Sit alongside your child for extra guidance early on.',
          'Focus on effort and fun rather than speed or accuracy.',
        ];
    }
  }

  // ── Reusable themed icon badge for dialogs ─────────────────────────────
  Widget _dialogIconBadge(IconData icon, Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  // ── Reusable themed dialog shell ────────────────────────────────────────
  void _showThemedDialog({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required Widget content,
    String buttonLabel = 'GOT IT!',
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: ColorTheme.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogIconBadge(icon, accentColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: content,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info (i) dialog — disclaimer only ──────────────────────────────────
  void _showSubjectInfoDialog(BuildContext context) {
    _showThemedDialog(
      context: context,
      icon: Icons.privacy_tip_outlined,
      accentColor: ColorTheme.mutedGrey,
      title: 'Data Disclaimer',
      buttonLabel: 'CLOSE',
      content: const Text(
        'All analytical reports, performance bands, and trend metrics '
            'displayed in this section are generated based solely on '
            'interactions, completion rates, and behavioral data collected '
            'during active in-app gameplay sessions. These insights serve as '
            'formative guidance and should not be used as formal educational '
            'diagnostic assessments.',
        textAlign: TextAlign.justify,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          color: ColorTheme.mutedGrey,
          height: 1.4,
        ),
      ),
    );
  }

  // ── Learn More dialog — description + tips ─────────────────────────────
  void _showCategoryDetailsDialog(BuildContext context, ConstructInsight insight) {
    final tips = _getBandTips(insight.band);

    _showThemedDialog(
      context: context,
      icon: insight.construct.icon,
      accentColor: insight.band.color,
      title: '${insight.construct.label} Analysis',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: insight.band.color),
              const SizedBox(width: 4),
              Text(
                'Band: ${insight.band.label}',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: insight.band.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.description,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorTheme.brown,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'WHAT YOU CAN TRY',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: insight.band.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map(
                (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: insight.band.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ColorTheme.brown,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildSubjectIntro(),
                    const SizedBox(height: 30),
                    _buildDateRow(),
                    const SizedBox(height: 14),
                    _buildOverallAnalysis(),
                    const SizedBox(height: 14),
                    _buildConstructsBox(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header: Back arrow & info button ─────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: ColorTheme.deepNavyBlue,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: ColorTheme.deepNavyBlue,
              size: 22,
            ),
            onPressed: () => _showSubjectInfoDialog(context),
          ),
        ],
      ),
    );
  }

  // ── Subject Intro Header (Mascot + Title + Description) ───────────────

// ── Subject Intro Header (Mascot + Title + Description) ───────────────

  Widget _buildSubjectIntro() {
    final characterAsset = _getCharacterAsset(subject.name);
    final description = _getSubjectDescription(subject.name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          characterAsset,
          width: 90,
          height: 90,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Icon(
            subject.icon,
            size: 60,
            color: subject.color,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                subject.name.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: ColorTheme.deepNavyBlue,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.justify, // Added text justification
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: ColorTheme.brown,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Date Row ─────────────────────────────────────────────────────────

  Widget _buildDateRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formatDate(subject.lastUpdated),
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColorTheme.deepNavyBlue,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.calendar_today_rounded,
          size: 18,
          color: ColorTheme.deepNavyBlue,
        ),
      ],
    );
  }

  // ── Overall Analysis Card ────────────────────────────────────────────

  Widget _buildOverallAnalysis() {
    final bandCounts = <InsightBand, int>{};
    for (final insight in subject.insights) {
      bandCounts[insight.band] = (bandCounts[insight.band] ?? 0) + 1;
    }
    final overallBand = bandCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    ConstructInsight? strongest;
    for (final insight in subject.insights) {
      if (strongest == null ||
          insight.band.starCount > strongest.band.starCount) {
        strongest = insight;
      }
    }

    final summary = _overallSummary(subject.name, overallBand, strongest);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF7D070),
          width: 2.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Color(0xFFF7C325),
              ),
              SizedBox(width: 6),
              Text(
                'OVERALL  ANALYSIS',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF7C325),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: ColorTheme.brown,
            ),
          ),
        ],
      ),
    );
  }

  String _overallSummary(String subjectName, InsightBand overallBand,
      ConstructInsight? strongest) {
    final strongestLabel = strongest?.construct.label.toLowerCase() ?? 'skills';
    switch (overallBand) {
      case InsightBand.confident:
        return 'Performance in $subjectName is confident, with '
            '$strongestLabel standing out as a particular strength. '
            'Sessions show consistent, steady progress across the board.';
      case InsightBand.developing:
        return '$subjectName is developing well, with steady '
            'progress and $strongestLabel showing the strongest results '
            'so far. A few areas are still building consistency.';
      case InsightBand.emerging:
        return '$subjectName is still emerging, with '
            '$strongestLabel currently the strongest area. More sessions '
            'over time will help build a clearer, fuller picture.';
    }
  }

  // ── Constructs Box ───────────────────────────────────────────────────

  Widget _buildConstructsBox(BuildContext context) {
    final targetLabels = ['engagement', 'attention', 'focus'];
    final filteredInsights = subject.insights.where((insight) {
      final label = insight.construct.label.toLowerCase();
      return targetLabels.any((target) => label.contains(target));
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFA5E3E8),
          width: 2.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < filteredInsights.length; i++) ...[
            _buildConstructRow(context, filteredInsights[i]),
            if (i != filteredInsights.length - 1) ...[
              const SizedBox(height: 18),
              const Divider(
                color: Color(0xFFA5E3E8),
                thickness: 1.5,
              ),
              const SizedBox(height: 18),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildConstructRow(BuildContext context, ConstructInsight insight) {
    final constructColor = insight.band.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              insight.construct.icon,
              size: 22,
              color: constructColor,
            ),
            const SizedBox(width: 10),
            Text(
              insight.construct.label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: constructColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          insight.description,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: ColorTheme.brown,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () => _showCategoryDetailsDialog(context, insight),
              style: ElevatedButton.styleFrom(
                backgroundColor: constructColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'LEARN MORE  >',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}