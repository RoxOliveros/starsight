import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ForestDatabaseService {
  static String? activeChildId;

  static const int _maxStoredCycles = 2;

  static Future<void> saveGameData({
    required String gameId,
    required String activityName,
    required List<String> emotions,
    required int totalTaps,
    required int mistakes,
    required String timePlayedSeconds,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || activeChildId == null) return;
      final uid = user.uid;

      final trackerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(activeChildId)
          .collection('category_progress')
          .doc('alphabet_forest');

      // 1. Get the current cycle
      final trackerDoc = await trackerRef.get();
      int currentCycle = 1;

      if (trackerDoc.exists && trackerDoc.data()!.containsKey('currentCycle')) {
        currentCycle = trackerDoc.data()!['currentCycle'];
      } else {
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));
      }

      int slot = ((currentCycle - 1) % _maxStoredCycles) + 1;
      DocumentReference<Map<String, dynamic>> currentCycleRef = trackerRef
          .collection('cycles')
          .doc('cycle_$slot');

      // 2. SMARTER DUPLICATE CHECK
      final gamesSnapshot = await currentCycleRef
          .collection('games_played')
          .get();
      int totalGamesInCycle = gamesSnapshot.docs.length;
      bool gameAlreadyPlayed = gamesSnapshot.docs.any(
        (doc) => doc.id == gameId,
      );

      // Only start a new cycle IF the forest is 100% complete (24 games) AND they replay a game
      if (totalGamesInCycle >= 5 && gameAlreadyPlayed) {
        currentCycle++;
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));

        slot = ((currentCycle - 1) % _maxStoredCycles) + 1;
        currentCycleRef = trackerRef.collection('cycles').doc('cycle_$slot');

        await _clearCycleSlot(currentCycleRef);
      }

      // 3. Save the data to the correct cycle
      final saveRef = currentCycleRef;

      // Timestamp the cycle itself so the report knows when this playthrough started
      await saveRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'playthroughNumber': currentCycle,
      }, SetOptions(merge: true));

      // Save the actual game metrics
      await saveRef.collection('games_played').doc(gameId).set({
        'activityName': activityName,
        'emotions': emotions,
        'totalTaps': totalTaps,
        'mistakes': mistakes,
        'timePlayedSeconds': timePlayedSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Cycle Tracking Error: $e");
    }
  }

  /// Wipes a rotating cycle slot's old games and cached report before it
  /// gets reused for a new playthrough, so old and new data never mix.
  static Future<void> _clearCycleSlot(
    DocumentReference<Map<String, dynamic>> cycleRef,
  ) async {
    final oldGames = await cycleRef.collection('games_played').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in oldGames.docs) {
      batch.delete(doc.reference);
    }
    batch.set(cycleRef, {
      'cachedReportData': FieldValue.delete(),
      'cachedReportCount': FieldValue.delete(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}
