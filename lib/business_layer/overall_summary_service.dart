import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'CategorySummaryService.dart';
import 'child_name_lookup.dart';
import 'forest_progress_service.dart';
import 'town_progress_service.dart';
import 'arctic_progress_service.dart';
import 'lagoon_progress_service.dart';
import 'puzzle_progress_service.dart';

/// The finished summary shown on the child screen.
class OverallSummary {
  final String text;

  /// How many subjects (that have been played) were used for this summary.
  final int categoriesIncluded;
  final int categoriesTotal;

  const OverallSummary({
    required this.text,
    required this.categoriesIncluded,
    required this.categoriesTotal,
  });
}

class _CategoryReport {
  final String id;
  final String name;
  final String overall;
  final int playthrough;
  final int count;

  const _CategoryReport({
    required this.id,
    required this.name,
    required this.overall,
    required this.playthrough,
    required this.count,
  });
}

class _Candidate {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final int playthrough;
  const _Candidate(this.doc, this.playthrough);
}

/// Builds one "all subjects" summary.
///
/// For every subject that has been played it makes sure the category report
/// exists and is up to date (using the SAME cache fields as
/// CategoryReportScreen, so the parent never has to open each subject), then
/// summarizes only those reports' overall analysis. The summary itself never
/// sees raw game data.
///
/// NOTE: the per-category part mirrors CategoryReportScreen._loadSpecificCycle.
/// If you change cachedReportVersion or how that screen builds a report,
/// change it here too (or refactor the screen to call this).
class OverallSummaryService {
  static const int _version = 1;
  static const int _maxStoredCycles = 2;
  static const int _categoryReportCacheVersion = 3; // same as the screen

  /// Same ids used in category_progress/{id}. Order = order used in the prompt.
  static const Map<String, String> categoryNames = {
    'alphabet_forest': 'Alphabet Forest',
    'lumi_town': 'Lumi Town',
    'arctic_numberland': 'Arctic Numberland',
    'discovery_lagoon': 'Discovery Lagoon',
    'puzzle_glade': 'Puzzle Glade',
  };

  static const Duration _requestTimeout = Duration(seconds: 40);

  static int _totalGamesFor(String categoryId, int fallback) {
    switch (categoryId) {
      case 'alphabet_forest':
        return ForestProgressService.totalLevels;
      case 'lumi_town':
        return TownProgressService.totalLevels;
      case 'arctic_numberland':
        return ArcticProgressService.totalLevels;
      case 'discovery_lagoon':
        return LagoonProgressService.totalLevels;
      case 'puzzle_glade':
        return PuzzleProgressService.totalLevels;
      default:
        return fallback;
    }
  }

  /// Returns null when the child hasn't played anything yet.
  /// Throws [ReportGenerationException] if nothing could be built.
  ///
  /// The child's nickname is read fresh from Firestore on every call, so a
  /// rename is always picked up. [fallbackName] is only used when that read
  /// isn't possible (e.g. offline).
  static Future<OverallSummary?> load({
    required String childId,
    String? fallbackName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final childRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children')
        .doc(childId);

    // null = couldn't check (offline): trust saved reports, like the screen.
    final checkedChildName = await tryGetChildDisplayName(childId);
    final reportChildName = checkedChildName ?? fallbackName ?? childId;

    final errors = <Object>[];
    final results = await Future.wait(
      categoryNames.entries.map((entry) async {
        try {
          return await _reportFor(
            categoryRef: childRef
                .collection('category_progress')
                .doc(entry.key),
            id: entry.key,
            name: entry.value,
            reportChildName: reportChildName,
            checkedChildName: checkedChildName,
          );
        } catch (e) {
          print('OverallSummaryService: ${entry.key} failed: $e');
          errors.add(e);
          return null;
        }
      }),
    );
    final reports = results.whereType<_CategoryReport>().toList();

    if (reports.isEmpty) {
      if (errors.isNotEmpty) {
        final first = errors.first;
        if (first is ReportGenerationException) throw first;
        throw ReportGenerationException(
          CategorySummaryService.looksLikeNetworkError(first)
              ? ReportErrorType.noInternet
              : ReportErrorType.serviceError,
        );
      }
      return null; // nothing played yet
    }

    final signature = _signature(reports, reportChildName);
    final childDoc = await childRef.get();
    final data = childDoc.data();

    // Nothing changed since the last summary -> reuse it, no AI call.
    if (data?['overallSummarySignature'] == signature &&
        data?['overallSummaryText'] is String) {
      return OverallSummary(
        text: data!['overallSummaryText'] as String,
        categoriesIncluded: reports.length,
        categoriesTotal: categoryNames.length,
      );
    }

    final text = await _generate(childName: reportChildName, reports: reports);

    try {
      await childRef.set({
        'overallSummaryText': text,
        'overallSummarySignature': signature,
      }, SetOptions(merge: true));
    } catch (e) {
      print('OverallSummaryService: could not cache summary: $e');
    }

    return OverallSummary(
      text: text,
      categoriesIncluded: reports.length,
      categoriesTotal: categoryNames.length,
    );
  }

  static String _signature(List<_CategoryReport> reports, String childName) {
    final parts = reports
        .map((r) => '${r.id}:${r.playthrough}:${r.count}')
        .join('|');
    return '$parts|$childName|v$_version';
  }

  /// Returns this subject's up-to-date report for its newest playthrough that
  /// has games, generating + caching it if it's missing or outdated.
  /// Returns null if the subject hasn't been played.
  static Future<_CategoryReport?> _reportFor({
    required DocumentReference<Map<String, dynamic>> categoryRef,
    required String id,
    required String name,
    required String reportChildName,
    required String? checkedChildName,
  }) async {
    final slotDocs = await Future.wait(
      List.generate(_maxStoredCycles, (i) => i + 1).map(
        (slot) => categoryRef.collection('cycles').doc('cycle_$slot').get(),
      ),
    );

    final candidates = <_Candidate>[];
    for (var i = 0; i < slotDocs.length; i++) {
      final doc = slotDocs[i];
      if (!doc.exists) continue;
      final playthrough =
          (doc.data()?['playthroughNumber'] as num?)?.toInt() ?? (i + 1);
      candidates.add(_Candidate(doc, playthrough));
    }
    candidates.sort((a, b) => b.playthrough.compareTo(a.playthrough));

    for (final c in candidates) {
      final games = await c.doc.reference.collection('games_played').get();
      if (games.docs.isEmpty) continue;

      final attentionStates = <String>[];
      var totalMistakes = 0;
      final distinctLevels = <String>{};

      for (final doc in games.docs) {
        final gData = doc.data();
        final gameId = gData['gameId'] as String? ?? doc.id;

        if (id == 'alphabet_forest' && gameId.startsWith('letter_')) {
          final lvl = ForestProgressService.levelNumberForLetter(
            gameId.split('_').last,
          );
          distinctLevels.add(lvl != null ? 'Level $lvl' : gameId);
        } else {
          distinctLevels.add(gameId);
        }

        totalMistakes += (gData['mistakes'] as num?)?.toInt() ?? 0;
        attentionStates.addAll(List<String>.from(gData['emotions'] ?? []));
      }

      final totalAttempts = games.docs.length;
      final cycleData = c.doc.data() ?? {};

      // Same cache check as CategoryReportScreen.
      final cached = cycleData['cachedReportData'];
      if (cycleData['cachedReportCount'] == totalAttempts &&
          cycleData['cachedReportVersion'] == _categoryReportCacheVersion &&
          (checkedChildName == null ||
              cycleData['cachedReportChildName'] == checkedChildName) &&
          cached is Map &&
          cached['overallAnalysis'] is String) {
        return _CategoryReport(
          id: id,
          name: name,
          overall: _stripDisclaimer(cached['overallAnalysis'] as String),
          playthrough: c.playthrough,
          count: totalAttempts,
        );
      }

      // Missing or outdated -> build it now, exactly like the screen would.
      final playedGameIds = distinctLevels.toList();
      final summaryMap = await CategorySummaryService.generateCategoryReport(
        categoryName: name,
        childName: reportChildName,
        completedGameIds: playedGameIds,
        totalCategoryGames: _totalGamesFor(id, playedGameIds.length),
        attentionStates: attentionStates,
        totalMistakes: totalMistakes,
        totalAttempts: totalAttempts,
      );

      await c.doc.reference.set({
        'cachedReportCount': totalAttempts,
        'cachedReportVersion': _categoryReportCacheVersion,
        'cachedReportChildName': reportChildName,
        'cachedReportData': summaryMap,
      }, SetOptions(merge: true));

      return _CategoryReport(
        id: id,
        name: name,
        overall: _stripDisclaimer(summaryMap['overallAnalysis'] as String),
        playthrough: c.playthrough,
        count: totalAttempts,
      );
    }
    return null;
  }

  /// CategorySummaryService appends "*Please note: ... partial progress ...*"
  /// to overallAnalysis. It's noise for the prompt, so drop it.
  static String _stripDisclaimer(String text) {
    return text
        .replaceAll(RegExp(r'\s*\*Please note:.*$', dotAll: true), '')
        .trim();
  }

  static Future<String> _generate({
    required String childName,
    required List<_CategoryReport> reports,
  }) async {
    final apiKey = CategorySummaryService.apiKey;
    if (apiKey.isEmpty) {
      print('GEMINI_API_KEY is missing');
      throw const ReportGenerationException(ReportErrorType.serviceError);
    }

    final model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final areaText = reports
        .map((r) => '### ${r.name}\n${r.overall}')
        .join('\n\n');
    final coverage =
        '${reports.length} of ${categoryNames.length} areas have been played so far';

    final prompt =
        '''
You are an expert early childhood educator writing ONE short overall summary for a parent about their child, $childName, across the learning areas they have played in the StarSight app.

Below is the overall analysis already written for each learning area ($coverage):

$areaText

IMPORTANT — this summary is written by students, not licensed professionals.
It must stay strictly observational:
- Do NOT give the parent any suggestions, recommendations, tips, or things to try. Only describe what was observed and what the pattern generally indicates.
- Do NOT assign labels, levels, bands, grades, or scores of any kind.
- Do NOT quote any numbers or percentages; describe amounts in words like "most of the time" or "occasionally".
- Use soft wording such as "appeared to" or "seemed to" for anything based on camera estimates.
- Do NOT describe or guess the child's emotions or mood.
- Only mention learning areas that appear above. Do not imply anything about areas that are not listed.
- Do NOT go area by area or repeat the sentences above. Combine them into one picture: what stayed consistent across areas (engagement, attention, focus) and, if there is a clear difference between areas, mention it gently.

Write 3-4 sentences in plain language a parent can easily follow.

Provide a JSON response strictly matching this structure (no other keys):
{
  "overallSummary": "3-4 sentences."
}
''';

    try {
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(_requestTimeout);

      final raw = response.text;
      if (raw == null) {
        throw const ReportGenerationException(ReportErrorType.serviceError);
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['overallSummary'] is! String ||
          (decoded['overallSummary'] as String).trim().isEmpty) {
        throw const ReportGenerationException(ReportErrorType.serviceError);
      }
      return (decoded['overallSummary'] as String).trim();
    } on ReportGenerationException {
      rethrow;
    } catch (e) {
      print('Gemini overall summary error: $e');
      throw ReportGenerationException(
        CategorySummaryService.looksLikeNetworkError(e)
            ? ReportErrorType.noInternet
            : ReportErrorType.serviceError,
      );
    }
  }
}
