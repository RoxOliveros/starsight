import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/CategorySummaryService.dart';
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
  Map<String, dynamic>? _reportData; // CHANGED: Now expects our JSON Map!
  String? _error;
  int _currentCycle = 1;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Find the current active cycle
      final trackerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('category_progress')
          .doc(widget.categoryId);

      final trackerDoc = await trackerRef.get();
      if (trackerDoc.exists && trackerDoc.data()!.containsKey('currentCycle')) {
        _currentCycle = trackerDoc.data()!['currentCycle'];
      }

      // 2. Query the NEW cycle path!
      var snapshot = await trackerRef
          .collection('cycles')
          .doc('cycle_$_currentCycle')
          .collection('games_played')
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error =
              "No games played in ${widget.categoryName} yet! Let's explore some activities.";
        });
        return;
      }

      // 3. Aggregate data from this specific cycle
      List<String> playedGameIds = [];
      List<String> allEmotions = [];
      int totalMistakes = 0;

      for (var doc in snapshot.docs) {
        playedGameIds.add(doc.id);
        totalMistakes += (doc.data()['mistakes'] as num?)?.toInt() ?? 0;
        var emotions = List<String>.from(doc.data()['emotions'] ?? []);
        allEmotions.addAll(emotions);
      }

      int totalCategoryGames = widget.categoryId == 'alphabet_forest' ? 24 : 10;

      // 4. Call Gemini and receive the Map
      Map<String, dynamic> summaryMap =
          await CategorySummaryService.generateCategoryReport(
            categoryName: widget.categoryName,
            childName: widget.childName,
            completedGameIds: playedGameIds,
            totalCategoryGames: totalCategoryGames,
            aggregatedEmotions: allEmotions,
            totalMistakes: totalMistakes,
          );

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

  // --- MODAL POPUP (Matches Leader's Design) ---
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
      ),
      body: SafeArea(
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        widget.categoryName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fredoka,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: ColorTheme.deepNavyBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "Cycle $_currentCycle Report",
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ColorTheme.brown,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

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
                              Icon(
                                Icons.auto_awesome,
                                color: ColorTheme.titleGold,
                              ),
                              const SizedBox(width: 8),
                              Text(
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
    );
  }
}
