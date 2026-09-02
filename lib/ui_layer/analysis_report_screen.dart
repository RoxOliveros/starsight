import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'parents_area_screen.dart';
import 'avatar_picker_dialog.dart'; // for kDefaultAvatarPath, AvatarStorage
import '../business_layer/orientation_service.dart';
import '../business_layer/database_service.dart';
import 'subject_analysis_screen.dart';

/// The four constructs every subject is analyzed on.
enum LearningConstruct { engagement, attention, focus, learning }

extension LearningConstructX on LearningConstruct {
  String get label {
    switch (this) {
      case LearningConstruct.engagement:
        return 'Engagement';
      case LearningConstruct.attention:
        return 'Attention';
      case LearningConstruct.focus:
        return 'Focus';
      case LearningConstruct.learning:
        return 'Learning';
    }
  }

  IconData get icon {
    switch (this) {
      case LearningConstruct.engagement:
        return Icons.emoji_emotions_rounded;
      case LearningConstruct.attention:
        return Icons.visibility_rounded;
      case LearningConstruct.focus:
        return Icons.center_focus_strong_rounded;
      case LearningConstruct.learning:
        return Icons.trending_up_rounded;
    }
  }
}

/// Relative band, already computed upstream — never a raw number. Shown
/// to parents as a short word plus a simple 1–3 star glance, never a
/// percentage or numeric score.
enum InsightBand { emerging, developing, confident }

extension InsightBandX on InsightBand {
  String get label {
    switch (this) {
      case InsightBand.emerging:
        return 'Emerging';
      case InsightBand.developing:
        return 'Developing';
      case InsightBand.confident:
        return 'Confident';
    }
  }

  /// 1–3 — used only to fill in stars, never displayed as a raw number.
  int get starCount {
    switch (this) {
      case InsightBand.emerging:
        return 1;
      case InsightBand.developing:
        return 2;
      case InsightBand.confident:
        return 3;
    }
  }

  Color get color {
    switch (this) {
      case InsightBand.emerging:
        return ColorTheme.orange;
      case InsightBand.developing:
        return ColorTheme.titleGold;
      case InsightBand.confident:
        return ColorTheme.teal;
    }
  }
}

enum InsightTrend { up, down, flat }

extension InsightTrendX on InsightTrend {
  IconData get icon {
    switch (this) {
      case InsightTrend.up:
        return Icons.trending_up_rounded;
      case InsightTrend.down:
        return Icons.trending_down_rounded;
      case InsightTrend.flat:
        return Icons.trending_flat_rounded;
    }
  }

  Color get color {
    switch (this) {
      case InsightTrend.up:
        return ColorTheme.teal;
      case InsightTrend.down:
        return ColorTheme.brown;
      case InsightTrend.flat:
        return ColorTheme.mutedGrey;
    }
  }
}

/// One construct's result for a subject: band + trend + the plain-language
/// sentence a teacher/parent actually reads. `lowConfidence` should be set
/// when tracker data was incomplete for the session(s) behind this insight.
class ConstructInsight {
  final LearningConstruct construct;
  final InsightBand band;
  final InsightTrend trend;
  final String description;
  final bool lowConfidence;

  const ConstructInsight({
    required this.construct,
    required this.band,
    required this.trend,
    required this.description,
    this.lowConfidence = false,
  });
}

class SubjectAnalysis {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String characterAsset; // e.g. assets/images/characters/cat.png
  final String tagline; // short, friendly one-liner under the subject name
  final List<ConstructInsight> insights;
  final DateTime lastUpdated;

  /// Number of game sessions played for this subject. Powers the
  /// "Games Played" / "Most Played" stat cards up top.
  /// TODO: replace with a real count from your analytics/session pipeline.
  final int sessionsPlayed;

  const SubjectAnalysis({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.characterAsset,
    required this.tagline,
    required this.insights,
    required this.lastUpdated,
    this.sessionsPlayed = 0,
  });
}

class AnalysisReportsScreen extends StatefulWidget {
  /// Optional — pass the currently selected child from Parent's Area so the
  /// report is scoped to them without an extra fetch. If null, this screen
  /// fetches the signed-in account's child itself.
  final ChildProfile? child;

  /// Child's age in years (fractional, e.g. 3.5 for 3 years 6 months).
  /// TODO: wire this to a real birthdate/age field once one exists on
  /// ChildProfile — for now it defaults to a value in your 3–4.5 range.
  final double age;

  const AnalysisReportsScreen({super.key, this.child, this.age = 3.5});

  @override
  State<AnalysisReportsScreen> createState() => _AnalysisReportsScreenState();
}

class _AnalysisReportsScreenState extends State<AnalysisReportsScreen> {
  bool _loading = true;
  String? _error;
  List<SubjectAnalysis> _subjects = [];

  // The actual child this report is for — either passed in via
  // widget.child, or fetched from the signed-in account below.
  ChildProfile? _resolvedChild;

  @override
  void initState() {
    super.initState();
    OrientationService.setPortrait();
    _load();
  }

  @override
  void dispose() {
    // Restore the app's default landscape lock for everything else.
    OrientationService.setLandscape();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      ChildProfile? child = widget.child;

      // No child was handed to us — go fetch the signed-in account's
      // child directly, the same way ParentsAreaScreen does.
      if (child == null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = "You're not signed in.";
          });
          return;
        }

        final rawChildren = await DatabaseService().getChildren();
        if (rawChildren.isEmpty) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = "No child profile found yet.";
          });
          return;
        }

        // Same avatar fallback logic as ParentsAreaScreen: use the real
        // avatar this account picked if the child doc has none of its own.
        final accountAvatarPath = await AvatarStorage.getSelectedAvatarPath();
        child = ChildProfile.fromMap(
          rawChildren.first['id'] as String,
          rawChildren.first,
          fallbackAvatarPath: accountAvatarPath,
        );
      }

      // Mock latency + mock data — replace with your real analysis call.
      // TODO: once wired up, fetch with
      // AnalysisService().getSubjectAnalyses(childId: child.id)
      await Future.delayed(const Duration(milliseconds: 400));
      final subjects = _mockAnalysesFor(child.id);
      if (!mounted) return;
      setState(() {
        _resolvedChild = child;
        _subjects = subjects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load the analysis. Pull down to try again.";
      });
    }
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
                onRefresh: _load,
                child: _buildBody(),
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
            color: ColorTheme.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildMessageState(
        icon: Icons.error_outline_rounded,
        message: _error!,
      );
    }

    if (_subjects.isEmpty) {
      return _buildMessageState(
        icon: Icons.insights_rounded,
        message: 'No analysis to show yet.',
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildRainbowTitle('STARSIGHT')),
          const SizedBox(height: 20), // Increased spacing
          _buildProfileHeader(),
          const SizedBox(height: 20), // Increased spacing
          _buildStatsRow(),
          const SizedBox(height: 45), // Increased spacing
          _buildReadyBanner(),
          const SizedBox(height: 35), // Increased spacing before navigation list
          _buildSubjectButtons(context),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  // ── Profile header (child avatar, name, age, info button) ────────────

  Widget _buildProfileHeader() {
    final name = _resolvedChild?.name ?? widget.child?.name ?? 'Demo Child';
    final avatarPath =
        _resolvedChild?.avatarPath ?? widget.child?.avatarPath ?? kDefaultAvatarPath;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorTheme.cardYellow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5),
                  border: Border.all(color: ColorTheme.orange, width: 2.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    avatarPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.face_rounded,
                      color: ColorTheme.deepNavyBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ColorTheme.deepNavyBlue,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.cake_rounded,
                            size: 14, color: ColorTheme.brown),
                        const SizedBox(width: 4),
                        Text(
                          _formatAge(widget.age),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ColorTheme.brown,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildInfoButton(),
            ],
          ),
        ),
        Positioned(
          top: -18,
          right: -20,
          child: Transform.rotate(angle: 0.4, child: _StarDecor(size: 50)),
        ),
        Positioned(
          bottom: -18,
          left: -20,
          child: Transform.rotate(angle: -0.3, child: _StarDecor(size: 50)),
        ),
      ],
    );
  }

  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: _showAgeExpectationDialog,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline_rounded,
          size: 25,
          color: ColorTheme.teal,
        ),
      ),
    );
  }

  String _formatAge(double years) {
    final wholeYears = years.floor();
    final months = ((years - wholeYears) * 12).round();
    if (months == 0) {
      return '$wholeYears ${wholeYears == 1 ? 'year' : 'years'} old';
    }
    return '$wholeYears yr $months mo old';
  }

  String _ageExpectationNote(double age) {
    if (age < 3.5) {
      return 'At this age, it\'s completely normal for focus to come in '
          'short bursts of around 5–10 minutes, for big feelings to show '
          'up quickly, and for sharing and turn-taking to still be a '
          'work in progress. Every child grows at their own pace.';
    } else if (age < 4.0) {
      return 'Around this age, children are usually growing more '
          'independent, holding focus for about 8–12 minutes at a time, '
          'and starting to follow two-step instructions — while still '
          'needing gentle reminders now and then. This is all typical.';
    }
    return 'At this age, many children can hold focus for up to 15 '
        'minutes, enjoy simple problem-solving, and are expressing '
        'themselves more clearly — though impulse control and patience '
        'are still very much developing. That\'s all part of healthy '
        'growth.';
  }

  void _showAgeExpectationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: ColorTheme.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: ColorTheme.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "What's typical at this age?",
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ColorTheme.deepNavyBlue,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(Icons.close_rounded,
                        color: ColorTheme.mutedGrey, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _ageExpectationNote(widget.age),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: ColorTheme.brown,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontWeight: FontWeight.w700,
                      color: ColorTheme.teal,
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

  Widget _buildMessageState({required IconData icon, required String message}) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        Icon(icon, color: ColorTheme.brown, size: 40),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.brown,
          ),
        ),
      ],
    );
  }

  Widget _buildRainbowTitle(String text) {
    const palette = [
      ColorTheme.titleSky,
      ColorTheme.titleGold,
      ColorTheme.titleOrange,
    ];
    int letterIndex = 0;
    final spans = <TextSpan>[];
    for (final char in text.split('')) {
      Color color;
      if (char.trim().isEmpty) {
        color = ColorTheme.brown;
      } else {
        final pairIndex = letterIndex ~/ 2;
        color = palette[pairIndex % palette.length];
        letterIndex++;
      }
      spans.add(TextSpan(text: char, style: TextStyle(color: color)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: AppTextStyles.fredoka,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        children: spans,
      ),
    );
  }

  // ── Stats row: games played (teal) + most played subject (orange) ────

  Widget _buildStatsRow() {
    final totalGames =
    _subjects.fold<int>(0, (sum, s) => sum + s.sessionsPlayed);

    SubjectAnalysis? topSubject;
    for (final s in _subjects) {
      if (topSubject == null || s.sessionsPlayed > topSubject.sessionsPlayed) {
        topSubject = s;
      }
    }

    final topSubjectName = topSubject != null
        ? topSubject.name.replaceFirst(' ', '\n')
        : '—';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard(
              color: const Color(0xFF56CCE2),
              value: '$totalGames',
              label: 'GAMES COMPLETED',
              valueFontSize: 40,
              infoTitle: 'Games Completed',
              infoMessage:
              'This counts every game session your child has finished '
                  'across all subjects.',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _buildStatCard(
              color: const Color(0xFFEE8A23),
              value: topSubjectName,
              label: 'MOST PLAYED SUBJECT',
              valueFontSize: 18,
              infoTitle: 'Most Played Subject',
              infoMessage:
              'This shows whichever subject your child has completed the '
                  'most game sessions in so far.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required Color color,
    required String value,
    required String label,
    required String infoTitle,
    required String infoMessage,
    double valueFontSize = 36,
  }) {
    const labelOverflow = 12.0;

    return Padding(
      padding: const EdgeInsets.only(top: labelOverflow),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            height: 120,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2.5),
            ),
            child: Center(
              child: Text(
                value,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ready banner: Lottie clapperboard + "Analysis Reports is Ready!" ───

  Widget _buildReadyBanner() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Lottie.asset(
            'assets/animations/movie_clapperboard.json',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Icon(
              Icons.movie_creation_outlined,
              size: 36,
              color: ColorTheme.deepNavyBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analysis Reports is Ready!',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ColorTheme.deepNavyBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Select a subject below to explore their insights.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorTheme.brown.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSubjectButtons(BuildContext context) {
    const rowColors = [
      Color(0xFFFCEFD1), // soft gold
      Color(0xFFD9F1F5), // soft teal
      Color(0xFFFBE1CB), // soft orange
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _subjects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        final bg = rowColors[index % rowColors.length];
        final lottieAsset = _getSubjectLottieAsset(subject.id);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubjectAnalysisScreen(subject: subject),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  child: Lottie.asset(
                    lottieAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => Icon(
                      subject.icon,
                      size: 26,
                      color: subject.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),
                      if (subject.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subject.tagline,
                          softWrap: true,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorTheme.brown,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: ColorTheme.brown.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  String _getSubjectLottieAsset(String id) {
    switch (id) {
      case 'alphabet_forest':
        return 'assets/animations/forest.json';
      case 'lumitown':
        return 'assets/animations/town.json';
      case 'arctic_numberland':
        return 'assets/animations/arctic.json';
      case 'discovery_lagoon':
        return 'assets/animations/lagoon.json';
      case 'puzzle_glade':
        return 'assets/animations/puzzle.json';
      default:
        return 'assets/animations/forest.json';
    }
  }

  // ---- Mock data -----------------------------------------------------

  List<SubjectAnalysis> _mockAnalysesFor(String childId) {
    final now = DateTime.now();
    final seed = childId.hashCode.abs();

    InsightBand bandAt(int i) =>
        InsightBand.values[(seed + i) % InsightBand.values.length];
    InsightTrend trendAt(int i) =>
        InsightTrend.values[(seed + i * 3) % InsightTrend.values.length];

    final subjectsSpec = [
      (
      'alphabet_forest',
      'Alphabet Forest',
      Icons.abc_rounded,
      ColorTheme.orange,
      'assets/images/avatars/avatar_dog.png',
      'Letters, sound, alphabet',
      ),
      (
      'lumitown',
      'Lumitown',
      Icons.science_rounded,
      ColorTheme.titleSky,
      'assets/images/avatars/avatar_owl.png',
      'Curious questions and cause-and-effect!',
      ),
      (
      'arctic_numberland',
      'Arctic Numberland',
      Icons.pin_rounded,
      ColorTheme.deepNavyBlue,
      'assets/images/avatars/avatar_penguin.png',
      'Counting, matching, and number play!',
      ),
      (
      'discovery_lagoon',
      'Discovery Lagoon',
      Icons.favorite_rounded,
      ColorTheme.titleGold,
      'assets/images/avatars/avatar_cat.png',
      'Kindness, sharing, and good choices!',
      ),
      (
      'puzzle_glade',
      'Puzzle Glade',
      Icons.extension_rounded,
      ColorTheme.teal,
      'assets/images/avatars/avatar_bunny.png',
      'Shapes, patterns, and problem-solving!',
      ),
    ];

    return List.generate(subjectsSpec.length, (s) {
      final (id, name, icon, color, characterAsset, tagline) =
      subjectsSpec[s];
      final insights = LearningConstruct.values.asMap().entries.map((entry) {
        final i = entry.key + s * 4;
        final construct = entry.value;
        return ConstructInsight(
          construct: construct,
          band: bandAt(i),
          trend: trendAt(i),
          description: _mockDescription(name, construct, bandAt(i)),
          lowConfidence: (seed + i) % 7 == 0,
        );
      }).toList();

      return SubjectAnalysis(
        id: id,
        name: name,
        icon: icon,
        color: color,
        characterAsset: characterAsset,
        tagline: tagline,
        insights: insights,
        lastUpdated: now.subtract(Duration(days: s)),
        sessionsPlayed: 4 + ((seed + s * 9) % 22),
      );
    });
  }

  String _mockDescription(
      String subject,
      LearningConstruct construct,
      InsightBand band,
      ) {
    switch (construct) {
      case LearningConstruct.engagement:
        switch (band) {
          case InsightBand.confident:
            return 'Starts $subject activities right away and often replays favorite games without prompting.';
          case InsightBand.developing:
            return 'Engages well once a game starts, with occasional pauses before beginning a new round.';
          case InsightBand.emerging:
            return 'Needs a little encouragement to start $subject games, but stays once playing.';
        }
      case LearningConstruct.attention:
        switch (band) {
          case InsightBand.confident:
            return 'Consistently looks at and taps the correct targets across most attempts.';
          case InsightBand.developing:
            return 'Attention is mostly on-target, with some looking away between rounds.';
          case InsightBand.emerging:
            return 'Attention shifts often; benefits from shorter activity bursts in $subject.';
        }
      case LearningConstruct.focus:
        switch (band) {
          case InsightBand.confident:
            return 'Stays on a single activity for extended stretches without switching away.';
          case InsightBand.developing:
            return 'Holds focus for the first part of a session, tapering off midway through.';
          case InsightBand.emerging:
            return 'Focus is brief and easily interrupted by other elements on screen.';
        }
      case LearningConstruct.learning:
        switch (band) {
          case InsightBand.confident:
            return 'Accuracy has steadily improved across recent $subject sessions.';
          case InsightBand.developing:
            return 'Showing gradual improvement, with performance still varying session to session.';
          case InsightBand.emerging:
            return 'Performance is still establishing a baseline; not enough sessions yet for a clear trend.';
        }
    }
  }
}

// ── Shared small decorative widget ──────────────────────────────────────

class _StarDecor extends StatelessWidget {
  final double size;

  const _StarDecor({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/night_star.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stack) => Icon(
        Icons.star_rounded,
        size: size,
        color: ColorTheme.titleGold,
      ),
    );
  }
}