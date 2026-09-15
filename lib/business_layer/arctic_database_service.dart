import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ArcticDatabaseService {
  static const int _gamesPerCycle = 20;

  static const int _maxStoredCycles = 2;
  static String? activeChildId;

  static Future<void> saveGameData({
    required String gameId,
    required int mistakes,
    required List<String> emotions,
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
          .doc('arctic_numberland');

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

      final gamesSnapshot = await currentCycleRef
          .collection('games_played')
          .get();
      final distinctGameIdsPlayed = gamesSnapshot.docs
          .map((doc) => doc.data()['gameId'] as String?)
          .whereType<String>()
          .toSet();
      final totalDistinctGamesInCycle = distinctGameIdsPlayed.length;
      final gameAlreadyPlayed = distinctGameIdsPlayed.contains(gameId);

      if (totalDistinctGamesInCycle >= _gamesPerCycle && gameAlreadyPlayed) {
        currentCycle++;
        await trackerRef.set({
          'currentCycle': currentCycle,
        }, SetOptions(merge: true));

        slot = ((currentCycle - 1) % _maxStoredCycles) + 1;
        currentCycleRef = trackerRef.collection('cycles').doc('cycle_$slot');

        await _clearCycleSlot(currentCycleRef);
      }

      final saveRef = currentCycleRef;

      await saveRef.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'playthroughNumber': currentCycle,
      }, SetOptions(merge: true));

      await saveRef.collection('games_played').add({
        'gameId': gameId,
        'mistakes': mistakes,
        'emotions': emotions,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving Arctic game data: $e");
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
