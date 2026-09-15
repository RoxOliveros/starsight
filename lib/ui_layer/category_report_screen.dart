import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/CategorySummaryService.dart';
import 'parents_area_screen.dart'; // lowercase

class CategoryReportScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String childName;

  const CategoryReportScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
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

  @override
  void initState() {
    super.initState();
    _initReportData();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String hour = d.hour > 12
        ? '${d.hour - 12}'
        : (d.hour == 0 ? '12' : '${d.hour}');
    String minute = d.minute.toString().padLeft(2, '0');
    String amPm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} - $hour:$minute $amPm';
  }

  // 1. Fetch how many cycles exist, then load the newest one
  Future<void> _initReportData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      final categoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(widget.childName)
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
    });

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      final cycleRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(widget.childName)
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

      // Alphabet Forest requires 5, Arctic Numberland requires 10
      int totalCategoryGames = (widget.categoryId == 'alphabet_forest')
          ? 5
          : 20;

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

  // --- DATA DISCLAIMER MODAL ---
  void _showDataDisclaimerDialog() {
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
            border: Border.all(color: Colors.grey.shade500, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.grey.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Data Disclaimer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'All analytical reports, performance bands, and trend metrics displayed in this section are generated based solely on interactions, completion rates, and behavioral data collected during active in-app gameplay sessions. These insights serve as formative guidance and should not be used as formal educational diagnostic assessments.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    height: 1.4,
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
                    backgroundColor: Colors.grey.shade500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
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

  // --- LEARN MORE DIALOG ---
  void _showLearnMoreDialog(
    String title,
    Map<String, dynamic> insightData,
    Color color,
    IconData icon,
  ) {
    String measurementExplanation = "";

    if (title.toLowerCase() == "engagement") {
      measurementExplanation =
          "Engagement is measured using facial expression metrics. The computer vision model detects emotional cues (such as happiness, surprise, or neutrality) while the child plays to understand their emotional response to the activity.";
    } else if (title.toLowerCase() == "attention") {
      measurementExplanation =
          "Attention is measured using gaze tracking. The system maps optical focus to observe whether the child's eyes remain fixed on the learning activities or if they frequently look away from the screen.";
    } else if (title.toLowerCase() == "focus") {
      measurementExplanation =
          "Focus is measured using motion tracking and interaction rates. It evaluates continuous physical engagement and task completion speed to determine if the child is working steadily without prolonged pauses.";
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTextStyles.fredoka,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: ColorTheme.mutedGrey,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: Colors.grey),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    insightData['band'] ?? '',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Shows the FULL detailed analysis here
              // Shows the FULL detailed analysis here
              Text(
                // Use the new detailed description, or fallback to the old description if cached
                insightData['detailedDescription'] ??
                    insightData['description'] ??
                    '',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  color: ColorTheme.brown,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Explanatory text defining the tracking metrics
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science_outlined, size: 18, color: color),
                        const SizedBox(width: 6),
                        Text(
                          "How it's measured",
                          style: TextStyle(
                            fontFamily: AppTextStyles.fredoka,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      measurementExplanation,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: ColorTheme.brown,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CONSTRUCT CARD (Matches Leader's Design) ---
  Widget _buildConstructCard(
    String title,
    Map<String, dynamic> insightData,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Learn More Button
              GestureDetector(
                onTap: () =>
                    _showLearnMoreDialog(title, insightData, color, icon),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Learn More",
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline_rounded, color: color, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: ColorTheme.cream),
          Row(
            children: [
              Icon(Icons.star_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                insightData['band'] ?? '',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Short Analysis preview
          Text(
            insightData['shortSummary'] ?? insightData['description'] ?? '',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              color: ColorTheme.brown,
              height: 1.35,
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
      appBar: AppBar(
        backgroundColor: ColorTheme.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ColorTheme.deepNavyBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: ColorTheme.deepNavyBlue,
              size: 24,
            ),
            onPressed: () => _showDataDisclaimerDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER & DROPDOWN ---
            Padding(
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
                  const SizedBox(height: 30),

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
                                      _slotToPlaythroughNumber[cycle] ?? cycle,
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
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: ColorTheme.teal,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ColorTheme.deepNavyBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
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
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // OVERALL ANALYSIS
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ColorTheme.titleGold,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: ColorTheme.titleGold,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "OVERALL ANALYSIS",
                                      style: TextStyle(
                                        fontFamily: AppTextStyles.fredoka,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: ColorTheme.titleGold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _reportData!['overallAnalysis'] ?? '',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 15,
                                    color: ColorTheme.brown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // DYNAMIC CARDS
                          if (_reportData!.containsKey('engagement'))
                            _buildConstructCard(
                              "Engagement",
                              _reportData!['engagement'],
                              ColorTheme.teal,
                              Icons.emoji_emotions_rounded,
                            ),
                          if (_reportData!.containsKey('attention'))
                            _buildConstructCard(
                              "Attention",
                              _reportData!['attention'],
                              ColorTheme.orange,
                              Icons.visibility_rounded,
                            ),
                          if (_reportData!.containsKey('focus'))
                            _buildConstructCard(
                              "Focus",
                              _reportData!['focus'],
                              ColorTheme.titleSky,
                              Icons.center_focus_strong_rounded,
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
}
