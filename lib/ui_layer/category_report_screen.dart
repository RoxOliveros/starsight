import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../business_layer/CategorySummaryService.dart';
import '../ui_layer/analysis_report_screen.dart'; // For ColorTheme and AppTextStyles
import 'parents_area_screen.dart';

class CategoryReportScreen extends StatefulWidget {
  final String categoryId; // e.g., 'alphabet_forest'
  final String categoryName; // e.g., 'Alphabet Forest'
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
  String _reportText = "";
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Fetch raw game data from Firestore
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('category_progress')
          .doc(widget.categoryId)
          .collection('games_played')
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _reportText =
              "No games played in ${widget.categoryName} yet! Let's explore some activities.";
        });
        return;
      }

      // 2. Aggregate the data
      List<String> playedGameIds = [];
      List<String> allEmotions = [];
      int totalMistakes = 0;

      for (var doc in snapshot.docs) {
        playedGameIds.add(doc.id);
        totalMistakes += (doc.data()['mistakes'] as num?)?.toInt() ?? 0;

        var emotions = List<String>.from(doc.data()['emotions'] ?? []);
        allEmotions.addAll(emotions);
      }

      // 3. Define total games for completion check (Alphabet Forest = 24)
      int totalCategoryGames = widget.categoryId == 'alphabet_forest' ? 24 : 10;

      // 4. Call Gemini to generate the report
      String summary = await CategorySummaryService.generateCategoryReport(
        categoryName: widget.categoryName,
        childName: widget.childName,
        completedGameIds: playedGameIds,
        totalCategoryGames: totalCategoryGames,
        aggregatedEmotions: allEmotions,
        totalMistakes: totalMistakes,
      );

      if (!mounted) return;
      setState(() {
        _reportText = summary;
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
        title: Text(
          "${widget.categoryName} Report",
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: ColorTheme.deepNavyBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: Lottie.asset('assets/animations/movie_clapperboard.json'),
            ),
            const SizedBox(height: 16),
            const Text(
              "Analyzing gameplay...",
              style: TextStyle(
                fontFamily: AppTextStyles.fredoka,
                fontSize: 18,
                color: ColorTheme.brown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(
            fontFamily: AppTextStyles.fredoka,
            color: Colors.red,
            fontSize: 16,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ColorTheme.teal, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                const Icon(
                  Icons.psychology_alt_rounded,
                  color: ColorTheme.orange,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  "Educator's Observation",
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fredoka,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ColorTheme.deepNavyBlue,
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1.5, color: ColorTheme.cream),
            Text(
              _reportText,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: ColorTheme.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
