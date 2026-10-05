import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/CategorySummaryService.dart';
import '../business_layer/forest_progress_service.dart';
import '../business_layer/arctic_progress_service.dart';
import '../business_layer/lagoon_progress_service.dart';
import '../business_layer/puzzle_progress_service.dart';
import 'parents_area_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryReportScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String childId;     // NEW: Firestore document ID, never changes
  final String childName;   // display name only

  const CategoryReportScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.childId,  // NEW
    required this.childName,
  });

  @override
  State<CategoryReportScreen> createState() => _CategoryReportScreenState();
}

class _CategoryReportScreenState extends State<CategoryReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;
  String? _error;

  String _cycleDateText = "";
  int _latestCycle = 1;
  int _selectedCycle = 1;
  List<int> _availableCycles = [1];

  static const int _maxStoredCycles = 2;
  Map<int, int> _slotToPlaythroughNumber = {};

  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initReportData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await _shouldShowDisclaimer() && mounted) {
        _showDataDisclaimerDialog();
      }
    });
  }

  void _onScroll() {
    final scrolled =
        _scrollController.hasClients && _scrollController.offset > 4;
    if (scrolled != _scrolled && mounted) {
      setState(() => _scrolled = scrolled);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // --- DYNAMIC HEADER HELPERS ---
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
    return 'assets/animations/characters/tofi_reading.webp'; // Fallback
  }

  String _getSubjectDescription(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('alphabet forest')) {
      return 'A fun learning area where children explore letters, sounds, and simple words through interactive activities.';
    } else if (lower.contains('lumitown')) {
      return 'A bright learning town where children build general knowledge through guided lessons, curious questions, and hands-on discovery activities.';
    } else if (lower.contains('arctic numberland')) {
      return 'A chilly numbers world where children practice counting, shapes, and simple math concepts through playful, interactive challenges.';
    } else if (lower.contains('discovery lagoon')) {
      return 'An underwater adventure where children explore science and nature through hands-on experiments and guided exploration activities.';
    } else if (lower.contains('puzzle glade')) {
      return 'A playful puzzle world where children build logic, memory, and problem-solving skills through fun, interactive brain games.';
    }
    return 'A fun learning area where children build new skills through interactive, age-appropriate activities.';
  }

  /// Turns a raw cycle number into parent/teacher-friendly wording —
  /// "1st Play", "2nd Play", "3rd Play", "4th Play"... instead of the
  /// internal "Playthrough" / "Cycle" terminology.
  String _playLabel(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) {
      return '${n}th Play';
    }
    switch (n % 10) {
      case 1:
        return '${n}st Play';
      case 2:
        return '${n}nd Play';
      case 3:
        return '${n}rd Play';
      default:
        return '${n}th Play';
    }
  }

  String _formatDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

//Dont show again disclaimer helpers (saved per account)
  String get _disclaimerPrefKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'hide_category_disclaimer_$uid';
  }

  Future<bool> _shouldShowDisclaimer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_disclaimerPrefKey) ?? false);
    } catch (_) {
      return true; // if storage fails, show it
    }
  }

  Future<void> _saveHideDisclaimer(bool hide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_disclaimerPrefKey, hide);
    } catch (_) {}
  }

  // 1. Fetch how many cycles exist, then load the newest one
  Future<void> _initReportData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      final categoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(widget.childId)        // was widget.childName
          .collection('category_progress')
          .doc(widget.categoryId);

      final trackerDoc = await categoryRef.get();

      if (trackerDoc.exists && trackerDoc.data()!.containsKey('currentCycle')) {
        _latestCycle = trackerDoc.data()!['currentCycle'];
      }

      // Only cycle_1..cycle_[_maxStoredCycles] ever get written to (the
      // database service rotates through them), so read exactly those
      // slots instead of assuming a doc exists for every play up to
      // _latestCycle.
      final slotDocs = await Future.wait(
        List.generate(_maxStoredCycles, (i) => i + 1).map(
              (slot) => categoryRef.collection('cycles').doc('cycle_$slot').get(),
        ),
      );

      final Map<int, int> slotToPlaythrough = {};
      final List<int> slotsWithData = [];
      for (final doc in slotDocs) {
        if (!doc.exists) continue;
        final slot = int.parse(doc.id.replaceFirst('cycle_', ''));
        // playthroughNumber is only present on docs written after this
        // rotation change; fall back to the slot number for older data.
        final playthroughNumber =
            (doc.data()?['playthroughNumber'] as int?) ?? slot;
        slotToPlaythrough[slot] = playthroughNumber;
        slotsWithData.add(slot);
      }

      if (slotsWithData.isEmpty) {
        // Nothing played yet — keep the old single-slot default so the
        // rest of the screen still has something sane to point at.
        slotToPlaythrough[1] = 1;
        slotsWithData.add(1);
      }

      // Most recent playthrough first.
      slotsWithData.sort(
            (a, b) =>
            (slotToPlaythrough[b] ?? b).compareTo(slotToPlaythrough[a] ?? a),
      );

      _slotToPlaythroughNumber = slotToPlaythrough;
      _availableCycles = slotsWithData;
      _selectedCycle = slotsWithData.first;

      await _loadSpecificCycle(_selectedCycle);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to initialize.";
          _isLoading = false;
        });
      }
    }
  }

  // 2. Load the data (with Smart Caching!)
  Future<void> _loadSpecificCycle(int cycleToLoad) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _cycleDateText = "";
      _scrolled = false; // the report is rebuilt at the top
    });

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final cycleRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(widget.childId)      // was widget.childName
          .collection('category_progress')
          .doc(widget.categoryId)
          .collection('cycles')
          .doc('cycle_$cycleToLoad');

      final cycleDoc = await cycleRef.get();

      // A. Grab the Date
      if (cycleDoc.exists && cycleDoc.data()!.containsKey('lastUpdated')) {
        DateTime dt = (cycleDoc.data()!['lastUpdated'] as Timestamp).toDate();
        _cycleDateText = _formatDateTime(dt);
      }

      // B. Grab the Games Played
      var snapshot = await cycleRef.collection('games_played').get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error =
          "No games played in ${_playLabel(_slotToPlaythroughNumber[cycleToLoad] ?? cycleToLoad)} yet!";
        });
        return;
      }

      List<String> allEmotions = [];
      int totalMistakes = 0;
      Set<String> distinctGameIds = {};

      for (var doc in snapshot.docs) {
        // Fallback to doc.id covers pre-migration docs — see note below.
        final gameId = doc.data()['gameId'] as String? ?? doc.id;
        distinctGameIds.add(gameId);

        totalMistakes += (doc.data()['mistakes'] as num?)?.toInt() ?? 0;
        var emotions = List<String>.from(doc.data()['emotions'] ?? []);
        allEmotions.addAll(emotions);
      }

      int totalAttempts = snapshot.docs.length;
      List<String> playedGameIds = distinctGameIds.toList();

      // C. CACHE CHECK: Did we already generate a report for this exact number of games?
      if (cycleDoc.exists &&
          cycleDoc.data()!.containsKey('cachedReportCount')) {
        int cachedCount = cycleDoc.data()!['cachedReportCount'];

        // If the game count hasn't changed, just use the saved report!
        if (cachedCount == totalAttempts &&
            cycleDoc.data()!.containsKey('cachedReportData')) {
          if (!mounted) return;
          setState(() {
            _reportData = Map<String, dynamic>.from(
              cycleDoc.data()!['cachedReportData'],
            );
            _isLoading = false;
          });
          return; // Stop here. Don't call the AI again.
        }
      }

      int totalCategoryGames;
      switch (widget.categoryId) {
        case 'alphabet_forest':
          totalCategoryGames = ForestProgressService.totalLevels;
          break;
        case 'arctic_numberland':
          totalCategoryGames = ArcticProgressService.totalLevels;
          break;
        case 'discovery_lagoon':
          totalCategoryGames = LagoonProgressService.totalLevels;
          break;
        case 'puzzle_glade':
          totalCategoryGames = PuzzleProgressService.totalLevels;
          break;
        default:
        // Unknown category id - fall back to what was actually played
        // rather than a guessed total.
          totalCategoryGames = playedGameIds.length;
      }

      Map<String, dynamic> summaryMap =
      await CategorySummaryService.generateCategoryReport(
        categoryName: widget.categoryName,
        childName: widget.childName,
        completedGameIds: playedGameIds,
        totalCategoryGames: totalCategoryGames,
        aggregatedEmotions: allEmotions,
        totalMistakes: totalMistakes,
      );

      // E. SAVE TO CACHE: Save this new report so it stays consistent next time
      await cycleRef.set({
        'cachedReportCount': totalAttempts,
        'cachedReportData': summaryMap,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _reportData = summaryMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load report. Please try again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _showDataDisclaimerDialog() {
    const accent = ColorTheme.deepNavyBlue;
    bool dontShowAgain = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: ColorTheme.cream,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: accent.withValues(alpha: 0.5), width: 3),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: accent,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                const Text(
                  'Before you read the report',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: ColorTheme.deepNavyBlue,
                  ),
                ),
                const SizedBox(height: 10),

                // Intro
                const Text(
                  'These insights come only from how your child plays '
                      'inside the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: ColorTheme.brown,
                  ),
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: accent),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'GOOD TO KNOW',
                              style: TextStyle(
                                fontFamily: AppTextStyles.fredoka,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final point in const [
                        'Reports are based on gameplay interactions, completion '
                            'rates, and behavior (such as expressions, eye '
                            'direction, and tapping) seen during play.',
                        'They are a helpful guide, not a medical, '
                            'psychological, or formal educational assessment.',
                        'Every child learns at their own pace. A quiet or '
                            'short session does not mean something is wrong.',
                        'Results can vary with lighting, camera view, and how '
                            'much your child played.',
                        'For any concerns about your child\'s development, '
                            'please talk to a teacher or a qualified '
                            'professional.',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                    color: ColorTheme.brown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Don't show again
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      setDialogState(() => dontShowAgain = !dontShowAgain),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(
                            value: dontShowAgain,
                            activeColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onChanged: (v) => setDialogState(
                                    () => dontShowAgain = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Don't show this again",
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: ColorTheme.brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (dontShowAgain) await _saveHideDisclaimer(true);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'I UNDERSTAND',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // // --- DATA DISCLAIMER MODAL (kept, no longer triggered by the (i) icon) ---
  // void _showDataDisclaimerDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => Dialog(
  //       backgroundColor: Colors.transparent,
  //       insetPadding: const EdgeInsets.symmetric(horizontal: 24),
  //       child: Container(
  //         padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
  //         decoration: BoxDecoration(
  //           color: ColorTheme.cream,
  //           borderRadius: BorderRadius.circular(24),
  //           border: Border.all(color: Colors.grey.shade500, width: 2.5),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.grey.withOpacity(0.25),
  //               blurRadius: 14,
  //               offset: const Offset(0, 6),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               width: 56,
  //               height: 56,
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.withOpacity(0.15),
  //                 shape: BoxShape.circle,
  //               ),
  //               child: Icon(
  //                 Icons.privacy_tip_outlined,
  //                 color: Colors.grey.shade600,
  //                 size: 28,
  //               ),
  //             ),
  //             const SizedBox(height: 12),
  //             Text(
  //               'Data Disclaimer',
  //               textAlign: TextAlign.center,
  //               style: TextStyle(
  //                 fontFamily: AppTextStyles.fredoka,
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.w800,
  //                 color: Colors.grey.shade700,
  //               ),
  //             ),
  //             const SizedBox(height: 14),
  //             Container(
  //               padding: const EdgeInsets.all(14),
  //               decoration: BoxDecoration(
  //                 color: Colors.white,
  //                 borderRadius: BorderRadius.circular(16),
  //               ),
  //               child: Text(
  //                 'All analytical reports, performance bands, and trend metrics displayed in this section are generated based solely on interactions, completion rates, and behavioral data collected during active in-app gameplay sessions. These insights serve as formative guidance and should not be used as formal educational diagnostic assessments.',
  //                 textAlign: TextAlign.justify,
  //                 style: TextStyle(
  //                   fontFamily: 'Nunito',
  //                   fontSize: 12.5,
  //                   fontStyle: FontStyle.italic,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.grey.shade600,
  //                   height: 1.4,
  //                 ),
  //               ),
  //             ),
  //             const SizedBox(height: 18),
  //             SizedBox(
  //               width: double.infinity,
  //               height: 40,
  //               child: ElevatedButton(
  //                 onPressed: () => Navigator.pop(context),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.grey.shade500,
  //                   elevation: 0,
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(20),
  //                   ),
  //                 ),
  //                 child: const Text(
  //                   'CLOSE',
  //                   style: TextStyle(
  //                     fontFamily: AppTextStyles.fredoka,
  //                     fontSize: 13,
  //                     fontWeight: FontWeight.w800,
  //                     color: Colors.white,
  //                     letterSpacing: 0.5,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  /// --- LEARN MORE DIALOG ---
  void _showLearnMoreDialog(
      String title,
      Map<String, dynamic> insightData,
      Color color,
      IconData icon,
      ) {
    // Plain-language explanation of how each indicator is measured.
    String measurementExplanation = "";
    String quickMeaning = "";

    if (title.toLowerCase() == "engagement") {
      quickMeaning = "How interested and happy your child seems while playing.";
      measurementExplanation =
      "We look at your child's facial expressions while they play, such as "
          "smiling or looking surprised, to understand how they feel about the "
          "activity.";
    } else if (title.toLowerCase() == "attention") {
      quickMeaning = "Whether your child's eyes stay on the activity.";
      measurementExplanation =
      "We track where your child is looking to see if they keep their eyes "
          "on the lesson or often look away from the screen.";
    } else if (title.toLowerCase() == "focus") {
      quickMeaning = "How steadily your child keeps working without long breaks.";
      measurementExplanation =
      "We watch how consistently your child taps, moves, and completes "
          "tasks to see if they keep going without long pauses.";
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),

              // One-line meaning
              Text(
                quickMeaning,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: ColorTheme.mutedGrey,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),

              // Scrollable content so long text never overflows
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // What we found
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.search_rounded, size: 16, color: color),
                                const SizedBox(width: 6),
                                Text(
                                  'WHAT WE FOUND',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                insightData['detailedDescription'] ??
                                    insightData['description'] ??
                                    '',
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColorTheme.brown,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // How it's measured
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'HOW WE MEASURE IT',
                                  style: TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                measurementExplanation,
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  color: ColorTheme.brown,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'GOT IT!',
                    style: TextStyle(
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

  // --- INDICATORS HEADER (title + info icon above the constructs box) ---
  Widget _buildIndicatorsHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const Text(
            ' WHAT WE OBSERVED',
            style: TextStyle(
              fontFamily: AppTextStyles.fredoka,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B6B8C),
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: _showIndicatorsInfoDialog,
            child: const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: Color(0xFF5B6B8C),
            ),
          ),
        ],
      ),
    );
  }

  // --- INDICATORS INFO DIALOG ---
  void _showIndicatorsInfoDialog() {
    const accent = ColorTheme.deepNavyBlue;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'What We Observed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'These are the three things we look at while your child plays: '
                      'Engagement (how interested and happy they seem), Attention '
                      '(whether their eyes stay on the activity), and Focus (how '
                      'steadily they keep working without long pauses). Together, '
                      'they give you a simple picture of how your child experienced '
                      'the game.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ColorTheme.brown,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'GOT IT!',
                    style: TextStyle(
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

  // --- CONSTRUCT ROW (one section inside the shared constructs box) ---
  Widget _buildConstructCard(
      String title,
      Map<String, dynamic> insightData,
      Color color,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Short Analysis preview
        SizedBox(
          width: double.infinity,
          child: Text(
            insightData['shortSummary'] ?? insightData['description'] ?? '',
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorTheme.brown,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Learn More pill button (bottom right)
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 100,
            height: 24,
            child: ElevatedButton(
              onPressed: () =>
                  _showLearnMoreDialog(title, insightData, color, icon),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LEARN MORE',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(width: 4),
                  // Icon(
                  //   Icons.chevron_right_rounded,
                  //   size: 11,
                  //   color: Colors.white,
                  // ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- CONSTRUCTS BOX (Engagement / Attention / Focus in one card) ---
  Widget _buildConstructsBox() {
    final entries = <Widget>[];
    final specs = [
      ('engagement', 'Engagement', ColorTheme.orange,
      Icons.emoji_emotions_rounded),
      ('attention', 'Attention', ColorTheme.teal, Icons.visibility_rounded),
      ('focus', 'Focus', ColorTheme.titleGold,
      Icons.center_focus_strong_rounded),
    ];

    for (final (key, title, color, icon) in specs) {
      if (!_reportData!.containsKey(key)) continue;
      if (entries.isNotEmpty) {
        entries.add(const SizedBox(height: 18));
        entries.add(const Divider(
          color: Color(0xFF6fd3e3),
          thickness: 1.2,
          height: 1.2,
          indent: 4,
          endIndent: 4,
        ));
        entries.add(const SizedBox(height: 18));
      }
      entries.add(_buildConstructCard(title, _reportData![key], color, icon));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6fd3e3).withOpacity(0.5),
          width: 3,
        ),
      ),
      child: Column(children: entries),
    );
  }

  // --- DISCLAIMER pinned at the bottom of the screen ---
  // Widget _buildDisclaimer() {
  //   return Container(
  //     width: double.infinity,
  //     margin: const EdgeInsets.fromLTRB(24, 4, 24, 12),
  //     padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFFFFDF5),
  //       borderRadius: BorderRadius.circular(18),
  //       border: Border.all(color: ColorTheme.mutedGrey, width: 2),
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             const Icon(
  //               Icons.privacy_tip_outlined,
  //               size: 16,
  //               color: ColorTheme.mutedGrey,
  //             ),
  //             const SizedBox(width: 6),
  //             const Text(
  //               'DATA DISCLAIMER',
  //               style: TextStyle(
  //                 fontFamily: AppTextStyles.fredoka,
  //                 fontSize: 12,
  //                 fontWeight: FontWeight.w800,
  //                 color: ColorTheme.mutedGrey,
  //                 letterSpacing: 0.5,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 6),
  //         const Text(
  //           'All analytical reports, performance bands, and trend metrics '
  //               'displayed in this section are generated based solely on '
  //               'interactions, completion rates, and behavioral data collected '
  //               'during active in-app gameplay sessions. These insights serve as '
  //               'formative guidance and should not be used as formal educational '
  //               'diagnostic assessments.',
  //           textAlign: TextAlign.justify,
  //           style: TextStyle(
  //             fontFamily: 'Nunito',
  //             fontSize: 9.5,
  //             fontStyle: FontStyle.italic,
  //             fontWeight: FontWeight.w600,
  //             color: ColorTheme.mutedGrey,
  //             height: 1.35,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTheme.cream,
      appBar: AppBar(
        backgroundColor: ColorTheme.cream,
        elevation: 0,
        // Stop Material 3 from tinting the app bar when content scrolls.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ColorTheme.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        // (i) icon removed — disclaimer now lives at the bottom of the screen.
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER & DROPDOWN ---
            // Solid background so nothing can show through the fixed header.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ColorTheme.cream,
                border: Border(
                  bottom: BorderSide(
                    color: _scrolled
                        ? ColorTheme.brown.withOpacity(0.2)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    // 1. THE DYNAMIC MOCKUP HEADER
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          _getCharacterAsset(widget.categoryName),
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => const Icon(
                            Icons.abc_rounded,
                            size: 60,
                            color: ColorTheme.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                widget.categoryName.toUpperCase(),
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
                                _getSubjectDescription(widget.categoryName),
                                textAlign: TextAlign.justify,
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
                    ),
                    const SizedBox(height: 18),

                    // Divider under the subject description
                    // const Divider(
                    //   color: Color(0xFFA5E3E8),
                    //   thickness: 1.5,
                    //   height: 1.5,
                    // ),
                    const SizedBox(height: 16),

                    // 2. THE DROPDOWN & CALENDAR DATE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // The Cycle Selector Dropdown
                        if (_availableCycles.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ColorTheme.teal,
                                width: 2,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedCycle,
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: ColorTheme.teal,
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  fontFamily: AppTextStyles.fredoka,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: ColorTheme.teal,
                                ),
                                items: _availableCycles.map((cycle) {
                                  return DropdownMenuItem<int>(
                                    value: cycle,
                                    child: Text(
                                      _playLabel(
                                        _slotToPlaythroughNumber[cycle] ??
                                            cycle,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  if (newValue != null &&
                                      newValue != _selectedCycle) {
                                    setState(() => _selectedCycle = newValue);
                                    _loadSpecificCycle(newValue);
                                  }
                                },
                              ),
                            ),
                          )
                        else
                          Text(
                            _playLabel(
                              _slotToPlaythroughNumber[_selectedCycle] ??
                                  _selectedCycle,
                            ),
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fredoka,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorTheme.deepNavyBlue,
                            ),
                          ),

                        const SizedBox(width: 8),

                        // The Date & Time (Now with flex wrapping!)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  _cycleDateText,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontFamily: AppTextStyles.fredoka,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: ColorTheme.deepNavyBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: ColorTheme.deepNavyBlue,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- REPORT BODY ---
            Expanded(
              child: _isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Lottie.asset(
                        'assets/animations/movie_clapperboard.json',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Analyzing gameplay...",
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 18,
                        color: ColorTheme.brown,
                      ),
                    ),
                  ],
                ),
              )
                  : _error != null
                  ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              )
                  : SingleChildScrollView(
                controller: _scrollController,
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // OVERALL ANALYSIS
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF7D070).withOpacity(0.5),
                          width: 3,
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
                              SizedBox(width: 8),
                              Text(
                                " OVERALL ANALYSIS",
                                style: TextStyle(
                                  fontFamily: AppTextStyles.fredoka,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF7C325),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              _reportData!['overallAnalysis'] ?? '',
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                                color: ColorTheme.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // "WHAT WE OBSERVED" heading with (i) info icon
                    _buildIndicatorsHeader(),
                    const SizedBox(height: 10),

                    // ENGAGEMENT / ATTENTION / FOCUS
                    _buildConstructsBox(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}