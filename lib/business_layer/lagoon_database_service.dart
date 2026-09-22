import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LagoonDatabaseService {
  static String? activeChildId;

  static const int _gamesPerCycle = 20;

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
          .doc('discovery_lagoon');

      //  Current cycle
      final trackerDoc = await trackerRef.get();
      final trackerData = trackerDoc.data();
      int currentCycle = (trackerData?['currentCycle'] as int?) ?? 1;
      if (trackerData == null || !trackerData.containsKey('currentCycle')) {
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));
      }

      int slot = ((currentCycle - 1) % _maxStoredCycles) + 1;
      DocumentReference<Map<String, dynamic>> cycleRef = trackerRef
          .collection('cycles')
          .doc('cycle_$slot');

      // Has the child finished a full playthrough and replayed a game
      final gamesSnapshot = await cycleRef.collection('games_played').get();
      final totalGamesInCycle = gamesSnapshot.docs.length;
      final gameAlreadyPlayed = gamesSnapshot.docs.any(
        (doc) => doc.id == gameId,
      );

      if (totalGamesInCycle >= _gamesPerCycle && gameAlreadyPlayed) {
        currentCycle++;
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));

        slot = ((currentCycle - 1) % _maxStoredCycles) + 1;
        cycleRef = trackerRef.collection('cycles').doc('cycle_$slot');

        await _clearCycleSlot(cycleRef);
      }

      // Save into the cycle
      await cycleRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'playthroughNumber': currentCycle,
      }, SetOptions(merge: true));

      await cycleRef.collection('games_played').doc(gameId).set({
        'gameId': gameId,
        'activityName': activityName,
        'emotions': emotions,
        'totalTaps': totalTaps,
        'mistakes': mistakes,
        'timePlayedSeconds': timePlayedSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Lagoon Cycle Tracking Error: $e');
    }
  }

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
