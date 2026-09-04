import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/CategorySummaryService.dart';
import '../ui_layer/analysis_report_screen.dart';
import 'Parents_Area_Screen.dart';

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
      final trackerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('category_progress')
          .doc(widget.categoryId)
          .get();

      if (trackerDoc.exists && trackerDoc.data()!.containsKey('currentCycle')) {
        _latestCycle = trackerDoc.data()!['currentCycle'];
      }

      // Populate the dropdown list (e.g., [1, 2, 3])
      _availableCycles = List.generate(_latestCycle, (index) => index + 1);
      _selectedCycle = _latestCycle;

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
          _error = "No games played in Cycle $cycleToLoad yet!";
        });
        return;
      }

      List<String> playedGameIds = [];
      List<String> allEmotions = [];
      int totalMistakes = 0;

      for (var doc in snapshot.docs) {
        playedGameIds.add(doc.id);
        totalMistakes += (doc.data()['mistakes'] as num?)?.toInt() ?? 0;
        var emotions = List<String>.from(doc.data()['emotions'] ?? []);
        allEmotions.addAll(emotions);
      }

      int currentGameCount = playedGameIds.length;

      // C. CACHE CHECK: Did we already generate a report for this exact number of games?
      if (cycleDoc.exists &&
          cycleDoc.data()!.containsKey('cachedReportCount')) {
        int cachedCount = cycleDoc.data()!['cachedReportCount'];

        // If the game count hasn't changed, just use the saved report!
        if (cachedCount == currentGameCount &&
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

      // D. GENERATE NEW REPORT (Only happens if data changed or no cache exists)
      // D. GENERATE NEW REPORT (Only happens if data changed or no cache exists)
      int totalCategoryGames = 10;
      if (widget.categoryId == 'alphabet_forest') {
        totalCategoryGames = 5;
      } else if (widget.categoryId == 'arctic_numberland') {
        totalCategoryGames =
            3; // <-- Temporarily set to 3 so it counts as "complete" for testing!
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
        'cachedReportCount': currentGameCount,
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

  // --- INSIGHT MODAL (Matches Leader's Design) ---
  void _showInsightModal(
    String title,
    Map<String, dynamic> insightData,
    Color color,
    IconData icon,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: ColorTheme.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 30,
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                "$title Analysis",
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Band: ${insightData['band']}",
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                insightData['description'] ?? '',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  color: ColorTheme.brown,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "WHAT YOU CAN TRY",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...(insightData['tips'] as List).map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                        child: CircleAvatar(radius: 4, backgroundColor: color),
                      ),
                      Expanded(
                        child: Text(
                          tip.toString(),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            color: ColorTheme.brown,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "GOT IT!",
                    style: TextStyle(
                      fontFamily: AppTextStyles.fredoka,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: ColorTheme.cream),
          Text(
            insightData['description'] ?? '',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              color: ColorTheme.brown,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showInsightModal(title, insightData, color, icon),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "LEARN MORE >",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
                                  child: Text("Playthrough $cycle"),
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
                          "Playthrough  $_selectedCycle",
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
